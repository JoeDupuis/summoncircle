class ContainersController < ApplicationController
  before_action :set_task

  def create
    # Always set building state
    @task.update!(container_status: "building")
    BuildDockerContainerJob.perform_later(@task)
    flash[:notice] = "Building container..."

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace("docker_controls", partial: "tasks/docker_controls", locals: { task: @task }),
          turbo_stream.prepend("flash-messages", partial: "application/flash_messages")
        ]
      }
      format.html { redirect_to @task }
    end
  end

  def destroy
    # Immediately set removing state
    @task.update!(container_status: "removing")
    RemoveDockerContainerJob.perform_later(@task)
    flash[:notice] = "Removing container..."

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace("docker_controls", partial: "tasks/docker_controls", locals: { task: @task }),
          turbo_stream.prepend("flash-messages", partial: "application/flash_messages")
        ]
      }
      format.html { redirect_to @task }
    end
  end

  private

  def set_task
    @task = Task.find(params[:task_id])
  end
end
