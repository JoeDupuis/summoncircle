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

    task.update!(
      container_status: "failed",
      container_id: nil,
      container_name: nil,
      docker_image_id: nil
    )

    # Create a run with the error information
    run = task.runs.create!(
      prompt: "Docker container rebuild failed",
      status: :failed,
      started_at: Time.current,
      completed_at: Time.current
    )

    run.steps.create!(
      raw_response: "Failed to rebuild Docker container\n\nError: #{e.message}\n\nBacktrace:\n#{e.backtrace.first(10).join("\n")}",
      type: "Step::Error",
      content: "Docker rebuild failed"
    )

    # Broadcast a redirect to show the task with the error run selected
    Turbo::StreamsChannel.broadcast_append_to(
      task,
      target: "body",
      partial: "shared/turbo_redirect",
      locals: { url: Rails.application.routes.url_helpers.task_path(task, selected_run_id: run.id) }
    )

    raise
  end
end
