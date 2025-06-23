class RebuildDockerContainerJob < ApplicationJob
  include DockerBuildErrorHandling

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

    handle_docker_build_error(task, e, error_type: "rebuild")

    raise
  end
end
