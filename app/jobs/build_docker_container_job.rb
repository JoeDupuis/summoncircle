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

    # Create a run with the error information
    run = task.runs.create!(
      prompt: "Docker container build failed",
      status: :failed,
      started_at: Time.current,
      completed_at: Time.current
    )

    run.steps.create!(
      raw_response: "Docker build error",
      type: "Step::Error",
      content: "Failed to build Docker container\n\nError: #{e.message}\n\nBacktrace:\n#{e.backtrace.first(10).join("\n")}"
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
