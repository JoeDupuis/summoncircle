class RemoveDockerContainerJob < ApplicationJob
  queue_as :default

  def perform(task)
    return unless task.container_id.present?

    container = Docker::Container.get(task.container_id)

    begin
      container.stop(t: 5)
    rescue => e
      Rails.logger.warn "Failed to stop container gracefully: #{e.message}"
    end

    container.delete(force: true)

    task.update!(
      container_id: nil,
      container_name: nil,
      container_status: nil
    )

    broadcast_docker_status(task)
  rescue Docker::Error::NotFoundError
    task.update!(
      container_id: nil,
      container_name: nil,
      container_status: nil
    )
    broadcast_docker_status(task)
  rescue => e
    Rails.logger.error "Failed to remove container: #{e.message}"
    raise
  end

  private

  def broadcast_docker_status(task)
    Turbo::StreamsChannel.broadcast_replace_to(
      task,
      target: "docker_controls",
      partial: "tasks/docker_controls",
      locals: { task: task }
    )
  end
end
