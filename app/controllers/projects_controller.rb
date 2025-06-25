class ProjectsController < ApplicationController
  def index
    @projects = Project.kept
  end

  def show
    @project = Project.find(params[:id])
  end

  def edit
    @project = Project.find(params[:id])
  end

  def update
    @project = Project.find(params[:id])
    if @project.update(project_params)
      redirect_to @project, notice: "Project was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
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
    params.require(:project).permit(:name, :description, :repository_url, :setup_script, :repo_path, :dev_dockerfile_path, :dev_container_port,
                                     secrets_attributes: [ :id, :key, :value, :_destroy ])
  end
end
