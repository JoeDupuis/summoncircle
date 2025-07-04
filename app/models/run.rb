class Run < ApplicationRecord
  include ActionView::RecordIdentifier
  include GitOperations
  belongs_to :task
  has_many :siblings, through: :task, source: :runs
  has_many :steps, -> { order(:id) }, dependent: :destroy

  enum :status, { pending: 0, running: 1, completed: 2, failed: 3 }, default: :pending

  validates :prompt, presence: true

  attr_accessor :skip_agent

  before_create :cancel_running_runs
  after_create_commit :enqueue_job, unless: :skip_agent
  after_update_commit :broadcast_update
  after_create_commit :broadcast_chat_append
  after_update_commit :broadcast_chat_replace
  after_create_commit :broadcast_initial_run

  def first_run?
    siblings.where.not(id: id).none?
  end

  def repo_states
    RepoState.joins(:step).where(step: steps)
  end

  def execute!
    running!
    update!(started_at: Time.current)

    begin
      clone_repository(task) if first_run? && should_clone_repository?
      run_setup_script

      if task.agent.mcp_sse_endpoint.present? && first_run?
        configure_mcp
      end

      container = create_container
      update!(container_id: container.id)
      container.start
      setup_container_files(container)

      processor = task.agent.log_processor_class.new
      processor.process_container(container, self)
      capture_repository_state(self)
      broadcast_refresh_task_actions_header
      push_changes_if_enabled
      completed!
      broadcast_refresh_task_header if first_run?
      broadcast_refresh_auto_push_form
    rescue => e
      error_message = "Error: #{e.message}\nBacktrace: #{e.backtrace.first(5).join("\n")}"
      Rails.logger.error "Run execution failed: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Create an error step with the error message
      steps.create!(raw_response: error_message, type: "Step::Error", content: error_message)
      failed!
    ensure
      update!(completed_at: Time.current, container_id: nil)
      save!
      container&.delete(force: true) if defined?(container)
    end
  end

  def broadcast_update
    broadcast_replace_later_to(task, target: self, partial: "tasks/run", locals: { run: self, show_chat: true })
  end

  def broadcast_chat_append
    broadcast_append_to(task, target: "chat-messages", partial: "runs/chat_item", locals: { run: self })
  end

  def broadcast_chat_replace
    broadcast_replace_later_to(task, target: dom_id(self, :chat_item), partial: "runs/chat_item", locals: { run: self })
  end

  def broadcast_refresh_auto_push_form
    broadcast_replace_to(task,
      target: "auto_push_form",
      partial: "tasks/auto_push_form",
      locals: { task: task })
  end

  def broadcast_refresh_task_actions_header
    task.reload
    broadcast_replace_later_to(task,
      target: "task-actions-header",
      partial: "tasks/actions_header",
      locals: { task: task })
  end

  def broadcast_initial_run
    if first_run?
      broadcast_replace_to(task,
        target: "loading-placeholder",
        partial: "tasks/run",
        locals: { run: self })
    else
      broadcast_append_to(task,
        target: "runs-list",
        partial: "tasks/run",
        locals: { run: self })
    end
  end

  def broadcast_refresh_task_header
    task.reload
    broadcast_replace_later_to(task,
      target: "task_header_content",
      partial: "tasks/header_content",
      locals: { task: task })
  end

  def total_cost
    steps.where.not(cost_usd: nil).sum(:cost_usd)
  end

  def total_tokens
    {
      input: steps.where.not(input_tokens: nil).sum(:input_tokens),
      output: steps.where.not(output_tokens: nil).sum(:output_tokens),
      cache_creation: steps.where.not(cache_creation_tokens: nil).sum(:cache_creation_tokens),
      cache_read: steps.where.not(cache_read_tokens: nil).sum(:cache_read_tokens)
    }
  end

  def stop_container
    return unless container_id.present?

    begin
      container = Docker::Container.get(container_id)
      container.stop

      steps.create!(
        raw_response: "Run cancelled",
        type: "Step::System",
        content: "This run was cancelled because a new run was started for the same task."
      )

      failed!
    rescue Docker::Error::NotFoundError
      Rails.logger.info "Container #{container_id} not found, may have already been stopped"
    rescue => e
      Rails.logger.error "Error stopping container #{container_id}: #{e.message}"
    end
  end

  private


  def create_container
    agent = task.agent
    command_template = first_run? ? agent.start_arguments : agent.continue_arguments
    command = command_template.map { |arg| arg.gsub("{PROMPT}", prompt) }

    binds = task.volume_mounts.includes(:volume).map(&:bind_string)

    Docker::Container.create(
      "Image" => agent.docker_image,
      "Cmd" => command,
      "Env" => task.docker_env_strings,
      "User" => agent.user_id.to_s,
      "WorkingDir" => task.agent.workplace_path,
      "HostConfig" => {
        "Binds" => binds
      }
    )
  end



  def should_clone_repository?
    task.project.repository_url.present?
  end



  def setup_container_files(container)
    agent = task.agent
    user = task.user

    if user.git_config.present? && agent.home_path.present?
      archive_file_to_container(container, user.git_config, File.join(agent.home_path, ".gitconfig"))
    end

    if user.instructions.present? && agent.instructions_mount_path.present?
      archive_file_to_container(container, user.instructions, agent.instructions_mount_path)
    end

    if user.ssh_key.present? && agent.ssh_mount_path.present?
      archive_file_to_container(container, user.ssh_key, agent.ssh_mount_path, 0o600)
    end
  end



  def configure_mcp
    agent = task.agent
    full_url = agent.mcp_sse_endpoint.end_with?("/mcp/sse") ? agent.mcp_sse_endpoint : "#{agent.mcp_sse_endpoint.chomp('/')}/mcp/sse"

    auth_token = Rails.application.config.x.mcp.auth_token

    mcp_container = Docker::Container.create(
      "Image" => agent.docker_image,
      "Cmd" => [
        "mcp", "add", "summoncircle", full_url, "-s", "user", "-t", "sse",
        "-H", "Authorization: Bearer #{auth_token}",
        "-H", "X-Task-Id: #{task.id}"
      ],
      "Env" => task.docker_env_strings,
      "User" => agent.user_id.to_s,
      "WorkingDir" => task.agent.workplace_path,
      "HostConfig" => {
        "Binds" => task.volume_mounts.includes(:volume).map(&:bind_string)
      }
    )

    mcp_container.start
    wait_result = mcp_container.wait(30)
    exit_code = wait_result["StatusCode"] if wait_result.is_a?(Hash)

    if exit_code && exit_code != 0
      logs = mcp_container.logs(stdout: true, stderr: true)
      clean_logs = logs.gsub(/^.{8}/m, "").force_encoding("UTF-8").scrub.strip
      raise "Failed to configure MCP: #{clean_logs}"
    end

    Rails.logger.info "MCP configured successfully for summoncircle at #{full_url}"
  rescue => e
    raise "MCP configuration error: #{e.message}"
  ensure
    mcp_container&.delete(force: true) if defined?(mcp_container)
  end

  def archive_file_to_container(container, content, destination_path, permissions = 0o644)
    target_dir = File.dirname(destination_path)

    container.exec([ "mkdir", "-p", target_dir ])

    encoded_content = Base64.strict_encode64(content)
    container.exec([ "sh", "-c", "echo '#{encoded_content}' | base64 -d > #{destination_path}" ])
    container.exec([ "chmod", permissions.to_s(8), destination_path ])
  end

  def run_setup_script
    return unless first_run? && task.project.setup_script.present?

    project = task.project
    repo_path = project.repo_path.presence || ""
    working_dir = task.workplace_mount.container_path
    setup_working_dir = File.join([ working_dir, repo_path.presence&.sub(/^\//, "") ].compact)

    setup_container = Docker::Container.create(
      "Image" => task.agent.docker_image,
      "Entrypoint" => [ "sh" ],
      "Cmd" => [ "-c", project.setup_script ],
      "WorkingDir" => setup_working_dir,
      "User" => task.agent.user_id.to_s,
      "Env" => task.docker_env_strings,
      "HostConfig" => {
        "Binds" => task.volume_mounts.includes(:volume).map(&:bind_string)
      }
    )

    setup_container.start
    wait_result = setup_container.wait(600)
    logs = setup_container.logs(stdout: true, stderr: true)
    clean_logs = logs.gsub(/^.{8}/m, "").force_encoding("UTF-8").scrub.strip
    exit_code = wait_result["StatusCode"] if wait_result.is_a?(Hash)

    if exit_code && exit_code != 0
      raise "Setup script failed with exit code #{exit_code}: #{clean_logs}"
    end

    steps.create!(
      raw_response: "Setup script executed",
      type: "Step::System",
      content: "Setup script executed successfully\n\nOutput:\n#{clean_logs}"
    )
  rescue => e
    raise "Setup script error: #{e.message}"
  ensure
    setup_container&.delete(force: true) if defined?(setup_container)
  end

  def push_changes_if_enabled
    return unless task.auto_push_enabled? && task.auto_push_branch.present?

    begin
      task.push_changes_to_branch("Auto-push from SummonCircle run #{id}")
      steps.create!(
        raw_response: "Auto-push completed",
        type: "Step::System",
        content: "Successfully pushed changes to branch: #{task.auto_push_branch}"
      )
    rescue => e
      steps.create!(
        raw_response: "Auto-push failed",
        type: "Step::Error",
        content: "Failed to push changes to branch: #{task.auto_push_branch}\n\nError: #{e.message}"
      )
    end
  end

  def enqueue_job
    RunJob.perform_later(id)
  end

  def cancel_running_runs
    task.runs.running.where.not(container_id: nil).find_each do |run|
      run.stop_container
    end
  end
end
