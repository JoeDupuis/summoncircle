class RebuildDockerContainerJob < ApplicationJob
  queue_as :default

  def perform(task)
    builder = DockerContainerBuilder.new(task)

    # Remove existing container and clear old image
    builder.remove_existing_container
    image_name = "summoncircle/task-#{task.id}-dev"
    builder.remove_old_image(image_name)

    # Build and run new container
    builder.build_and_run
  rescue => e
    Rails.logger.error "Failed to rebuild container: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    task.update!(container_status: "failed")
    builder.send(:broadcast_docker_status) if builder
    raise
  end
end
