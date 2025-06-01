class ProjectsController < ApplicationController
  def index
    @projects = Project.kept
  end

  def show
    @project = Project.find(params[:id])
  end

  def destroy
    @project = Project.find(params[:id])
    @project.discard
    redirect_to projects_url, notice: "Project was successfully archived."
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)
    if @project.save
      redirect_to @project, notice: "Project was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def project_params
    params.require(:project).permit(:name, :description, :repository_url, :setup_script)
  end
end
