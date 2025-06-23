class RunsController < ApplicationController
  before_action :set_task

  def create
    @run = @task.runs.build(run_params)

    respond_to do |format|
      if @run.save
        format.turbo_stream
        format.html { redirect_to task_path(@task), notice: "Run started successfully." }
      else
        format.turbo_stream { redirect_to task_path(@task), alert: "Failed to start run: #{@run.errors.full_messages.join(', ')}" }
        format.html { redirect_to task_path(@task), alert: "Failed to start run: #{@run.errors.full_messages.join(', ')}" }
      end
    end
  end

  private

  def set_task
    @task = Task.find(params[:task_id])
  end

  def run_params
    params.require(:run).permit(:prompt)
  end
end
