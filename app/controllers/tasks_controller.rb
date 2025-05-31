class TasksController < ApplicationController
  before_action :set_project
  before_action :set_task, only: :show

  def index
    @tasks = Task.includes(:agent, :project).order(created_at: :desc)
    @tasks = @tasks.where(project: @project) if @project.present?
    @task = Task.new
    @projects = Project.all
    @agents = Agent.all
  end

  def show
    @show_all_runs = params[:show_all_runs] == "true"
    if @show_all_runs
      @runs = @task.runs.order(created_at: :asc)
    else
      @runs = @task.runs.order(created_at: :desc).limit(1)
    end
  end

  def new
    @task = @project.tasks.new
    @task.agent_id = cookies[:preferred_agent_id] if cookies[:preferred_agent_id].present?
  end

  def create
    @task = Task.new(task_params.with_defaults(project_id: @project&.id))

    if @task.save
      cookies[:preferred_agent_id] = { value: @task.agent_id, expires: 1.year.from_now }
      @task.update!(started_at: Time.current)
      @task.run(params[:task][:prompt])
      redirect_to [ @project, @task ].compact, notice: "Task was successfully launched."
    else
      if @project.present?
        render :new, status: :unprocessable_entity
      else
        @tasks = Task.includes(:agent, :project).order(created_at: :desc)
        @projects = Project.all
        @agents = Agent.all
        render :index, status: :unprocessable_entity
      end
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id]) if params[:project_id].present?
  end

  def set_task
    if @project.present?
      @task = @project.tasks.find(params[:id])
    else
      @task = Task.find(params[:id])
    end
  end

  def task_params
    params.require(:task).permit(:agent_id, :project_id)
  end
end
