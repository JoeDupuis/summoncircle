class TasksController < ApplicationController
  before_action :set_project
  before_action :set_task, only: :show

  def index
    @tasks = @project.tasks.includes(:agent)
  end

  def show
    @runs = @task.runs.order(created_at: :asc)
  end

  def new
    @task = @project.tasks.new
  end

  def create
    @task = @project.tasks.new(task_params)
    if @task.save
      @task.update!(started_at: Time.current)
      @task.run(params[:task][:prompt]) if params[:task][:prompt].present?
      redirect_to [ @project, @task ], notice: "Task was successfully launched."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_task
    @task = @project.tasks.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:agent_id)
  end
end
