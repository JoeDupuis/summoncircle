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
      completed_at: Time.current,
      skip_agent: true
    )

    # Create error step with full details
    run.steps.create!(
      type: "Step::Error",
      raw_response: "Failed to build Docker container\n\nError: #{e.message}\n\nBacktrace:\n#{e.backtrace.first(10).join("\n")}",
      content: "Failed to build Docker container\n\nError: #{e.message}\n\nBacktrace:\n#{e.backtrace.first(10).join("\n")}"
    )

    # Create result step for chat display
    run.steps.create!(
      type: "Step::Result",
      raw_response: "Docker build failed",
      content: "Docker build failed"
    )

    # Update docker controls to show failed status
    Turbo::StreamsChannel.broadcast_replace_to(
      task,
      target: "docker_controls",
      partial: "tasks/docker_controls",
      locals: { task: task }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      task,
      target: "runs-list",
      partial: "tasks/runs_list",
      locals: { runs: task.runs }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      task,
      target: "chat-messages",
      partial: "tasks/chat_messages",
      locals: { runs: task.runs.order(:created_at) }
    )

    raise
  end
end
