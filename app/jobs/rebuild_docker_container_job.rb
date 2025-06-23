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
      raw_response: "Docker rebuild error",
      type: "Step::Error",
      content: "Failed to rebuild Docker container\n\nError: #{e.message}\n\nBacktrace:\n#{e.backtrace.first(10).join("\n")}"
    )

    # Broadcast updates
    Turbo::StreamsChannel.broadcast_replace_to(
      task,
      target: "docker_controls",
      partial: "tasks/docker_controls",
      locals: { task: task }
    )

    # Replace the runs list to show the new error run
    Turbo::StreamsChannel.broadcast_replace_to(
      task,
      target: "runs-list",
      partial: "tasks/runs_list",
      locals: { runs: task.runs.order(created_at: :desc).limit(20) }
    )

    # Create a turbo stream to switch to the Runs tab
    Turbo::StreamsChannel.broadcast_action_to(
      task,
      action: "append",
      target: "body",
      html: "<div data-controller=\"auto-tab-switch\" data-auto-tab-switch-target-value=\"steps\"></div>"
    )

    raise
  end
end
