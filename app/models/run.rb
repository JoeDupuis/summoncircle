class Run < ApplicationRecord
  belongs_to :task
  has_many :siblings, through: :task, source: :runs
  has_many :steps, dependent: :destroy

  enum :status, { pending: 0, running: 1, completed: 2, failed: 3 }, default: :pending

  def first_run?
    siblings.where.not(id: id).none?
  end

  def execute!
    running!
    update!(started_at: Time.current)

    original_docker_url = Docker.url
    begin
      configure_docker_host
      container = create_container
      container.start
      container.wait

      logs = container.logs(stdout: true, stderr: true)
      # Docker logs prefix each line with 8 bytes of metadata that we need to strip
      clean_logs = logs.gsub(/^.{8}/m, "").force_encoding("UTF-8").scrub.strip
      self.output = clean_logs
      completed!
    rescue => e
      self.output = "Error: #{e.message}"
      failed!
    ensure
      Docker.url = original_docker_url
      update!(completed_at: Time.current)
      save!
      container&.delete(force: true) if defined?(container)
    end
  end

  private

  def configure_docker_host
    agent = task.agent
    return unless agent.docker_host.present?

    Docker.url = agent.docker_host
  end

  def create_container
    agent = task.agent
    command_template = first_run? ? agent.start_arguments : agent.continue_arguments
    command = command_template.map { |arg| arg.gsub("{PROMPT}", prompt) }

    binds = []

    task.volume_mounts.includes(:volume).each do |volume_mount|
      volume = volume_mount.volume
      volume_name = "#{volume.name}_#{task_id}_volume"
      binds << "#{volume_name}:#{volume.path}"
    end

    Docker::Container.create(
      "Image" => agent.docker_image,
      "Cmd" => command,
      "WorkingDir" => "/workspace",
      "HostConfig" => {
        "Binds" => binds
      }
    )
  end
end
