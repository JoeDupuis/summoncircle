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
      completed!
    rescue => e
      error_message = "Error: #{filter_sensitive_info(e.message)}"
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
    filtered_logs = filter_sensitive_info(logs)
    step_data_list = processor_class.process(filtered_logs)

    step_data_list.each do |step_data|
      # Also filter individual step content
      if step_data[:content]
        step_data[:content] = filter_sensitive_info(step_data[:content])
      end
      if step_data[:raw_response]
        step_data[:raw_response] = filter_sensitive_info(step_data[:raw_response])
      end
      steps.create!(step_data)
    end
  end

  def clone_repository
    project = task.project
    repo_path = project.repo_path.presence || ""
    working_dir = task.workplace_mount.container_path
    clone_target = repo_path.empty? ? "." : repo_path.sub(/^\//, "")
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
      raise "Failed to clone repository: #{filter_sensitive_info(clean_logs)}"
    end
  rescue Docker::Error::NotFoundError => e
    raise "Alpine/git Docker image not found. Please pull alpine/git image."
  rescue => e
    # Re-raise with more context
    raise "Git clone error: #{filter_sensitive_info(e.message)} (#{e.class})"
  ensure
    git_container&.delete(force: true) if defined?(git_container)
  end

  def should_clone_repository?
    task.project.repository_url.present?
  end

  def filter_sensitive_info(message)
    return message unless task.user&.github_token.present?

    # Simple string replacement to filter out the token
    message.gsub(task.user.github_token, "[FILTERED]")
  end
end
