class ContainersController < ApplicationController
  before_action :set_task

  def create
    if @task.container_id.present?
      RebuildDockerContainerJob.perform_later(@task)
      flash[:notice] = "Rebuilding container..."
    else
      BuildDockerContainerJob.perform_later(@task)
      flash[:notice] = "Building container..."
    end

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
