class Run < ApplicationRecord
  belongs_to :task
  has_many :siblings, through: :task, source: :runs
  has_many :steps, dependent: :destroy

  enum :status, { pending: 0, running: 1, completed: 2, failed: 3 }, default: :pending

  after_update_commit :broadcast_update

  def first_run?
    siblings.where.not(id: id).none?
  end

  def execute!
    running!
    update!(started_at: Time.current)

    original_docker_url = Docker.url
    begin
      configure_docker_host
      clone_repository if first_run? && should_clone_repository?
      container = create_container
      container.start
      container.wait

      logs = container.logs(stdout: true, stderr: true)
      # Docker logs prefix each line with 8 bytes of metadata that we need to strip
      clean_logs = logs.gsub(/^.{8}/m, "").force_encoding("UTF-8").scrub.strip

      # Process logs and create steps
      create_steps_from_logs(clean_logs)
      capture_repository_state
      completed!
    rescue => e
      error_message = "Error: #{e.message}"
      steps.create!(raw_response: error_message, type: "Step::Text", content: error_message)
      failed!
    ensure
      Docker.url = original_docker_url
      update!(completed_at: Time.current)
      save!
      container&.delete(force: true) if defined?(container)
    end
  end

  private

  def broadcast_update
    broadcast_replace_later_to(task, target: self, partial: "tasks/run", locals: { run: self })
  end

  def configure_docker_host
    agent = task.agent
    return unless agent.docker_host.present?

    Docker.url = agent.docker_host
  end

  def create_container
    agent = task.agent
    command_template = first_run? ? agent.start_arguments : agent.continue_arguments
    command = command_template.map { |arg| arg.gsub("{PROMPT}", prompt) }

    Docker::Container.create(
      "Image" => agent.docker_image,
      "Cmd" => command,
      "Env" => agent.env_strings,
      "WorkingDir" => task.agent.workplace_path,
      "HostConfig" => {
        "Binds" => task.volume_mounts.includes(:volume).map(&:bind_string)
      }
    )
  end

  def create_steps_from_logs(logs)
    processor_class = task.agent.log_processor_class
    step_data_list = processor_class.process(logs)

    step_data_list.each do |step_data|
      steps.create!(step_data)
    end
  end

  def clone_repository
    project = task.project
    repo_path = project.repo_path.presence || ""
    working_dir = task.workplace_mount.container_path
    clone_target = repo_path.presence&.sub(/^\//, "") || "."
    repository_url = project.repository_url_with_token(task.user)

    git_container = Docker::Container.create(
      "Image" => "alpine/git",
      "Cmd" => [ "clone", repository_url, clone_target ],
      "WorkingDir" => working_dir,
      "HostConfig" => {
        "Binds" => [ task.workplace_mount.bind_string ]
      }
    )

    git_container.start
    wait_result = git_container.wait
    logs = git_container.logs(stdout: true, stderr: true)
    clean_logs = logs.gsub(/^.{8}/m, "").force_encoding("UTF-8").scrub.strip
    exit_code = wait_result["StatusCode"] if wait_result.is_a?(Hash)

    if exit_code && exit_code != 0
      raise "Failed to clone repository: #{clean_logs}"
    end

    fix_file_ownership(working_dir)
  rescue Docker::Error::NotFoundError => e
    raise "Alpine/git Docker image not found. Please pull alpine/git image."
  rescue => e
    # Re-raise with more context
    raise "Git clone error: #{e.message} (#{e.class})"
  ensure
    git_container&.delete(force: true) if defined?(git_container)
  end

  def should_clone_repository?
    task.project.repository_url.present?
  end

  def capture_repository_state
    return unless should_clone_repository?

    project = task.project
    repo_path = project.repo_path.presence || ""
    working_dir = task.workplace_mount.container_path
    
    git_working_dir = File.join([working_dir, repo_path.presence&.sub(/^\//, "")].compact)

    git_container = Docker::Container.create(
      "Image" => "alpine/git",
      "Cmd" => [ "diff" ],
      "WorkingDir" => git_working_dir,
      "HostConfig" => {
        "Binds" => [ task.workplace_mount.bind_string ]
      }
    )

    git_container.start
    wait_result = git_container.wait
    logs = git_container.logs(stdout: true, stderr: true)
    uncommitted_diff = logs.gsub(/^.{8}/m, "").force_encoding("UTF-8").scrub.strip

    repo_state_step = steps.create!(
      raw_response: "Repository state captured",
      type: "Step::System",
      content: "Repository state captured"
    )
    repo_state_step.repo_states.create!(
      uncommitted_diff: uncommitted_diff,
      repository_path: git_working_dir
    )
  rescue => e
    Rails.logger.error "Failed to capture repository state: #{e.message}"
  ensure
    git_container&.delete(force: true) if defined?(git_container)
  end

  def fix_file_ownership(working_dir)
    agent_uid = task.agent.user_id
    chown_container = Docker::Container.create(
      "Image" => "alpine",
      "Cmd" => [ "chown", "-R", "#{agent_uid}:#{agent_uid}", "." ],
      "WorkingDir" => working_dir,
      "HostConfig" => {
        "Binds" => [ task.workplace_mount.bind_string ]
      }
    )
    chown_container.start
    chown_container.wait
    chown_container.delete(force: true)
  end
end
