class BuildDockerContainerJob < ApplicationJob
  queue_as :default

  def perform(task)
    DockerContainerBuilder.new(task).build_and_run
  rescue => e
    Rails.logger.error "Failed to build/run container: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    task.update!(
      container_status: "failed",
      container_id: nil,
      container_name: nil,
      docker_image_id: nil
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      task,
      target: "docker_controls",
      partial: "tasks/docker_controls",
      locals: { task: task }
    )

    raise
  end
end
