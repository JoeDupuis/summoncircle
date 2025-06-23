class BuildDockerContainerJob < ApplicationJob
  include DockerBuildErrorHandling

  queue_as :default

  def perform(task)
    DockerContainerBuilder.new(task).build_and_run
  rescue => e
    Rails.logger.error "Failed to build/run container: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    handle_docker_build_error(task, e, error_type: "build")

    raise
  end
end
