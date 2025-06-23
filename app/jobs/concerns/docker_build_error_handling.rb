module DockerBuildErrorHandling
  extend ActiveSupport::Concern

  private

  def handle_docker_build_error(task, error, error_type: "build")
    task.update!(
      container_status: "failed",
      container_id: nil,
      container_name: nil,
      docker_image_id: nil
    )

    # Create a run with the error information
    run = task.runs.create!(
      prompt: "Docker container #{error_type} failed",
      status: :failed,
      started_at: Time.current,
      completed_at: Time.current
    )

    run.steps.create!(
      raw_response: "Failed to #{error_type} Docker container\n\nError: #{error.message}\n\nBacktrace:\n#{error.backtrace.first(10).join("\n")}",
      type: "Step::Error",
      content: "Docker #{error_type} failed"
    )

    # Update docker controls to show failed status
    Turbo::StreamsChannel.broadcast_replace_to(
      task,
      target: "docker_controls",
      partial: "tasks/docker_controls",
      locals: { task: task }
    )
  end
end
