class Run < ApplicationRecord
  belongs_to :task
  has_many :siblings, through: :task, source: :runs

  enum :status, { pending: 0, running: 1, completed: 2, failed: 3 }, default: :pending

  def first_run?
    siblings.where.not(id: id).none?
  end

  def execute!
    running!
    update!(started_at: Time.current)

    begin
      container = create_container
      container.start
      container.wait

      self.output = container.logs(stdout: true, stderr: true)
      completed!
    rescue => e
      self.output = "Error: #{e.message}"
      failed!
    ensure
      update!(completed_at: Time.current)
      save!
      container&.delete(force: true) if defined?(container)
    end
  end

  private

  def create_container
    agent = task.agent
    command_template = first_run? ? agent.start_arguments : agent.continue_arguments
    command = command_template.map { |arg| arg.gsub("{PROMPT}", prompt) }

    Docker::Container.create(
      "Image" => agent.docker_image,
      "Cmd" => command,
      "WorkingDir" => "/workspace",
      "HostConfig" => {
        "Binds" => [ "task_#{task_id}_volume:/workspace" ]
      }
    )
  end
end
