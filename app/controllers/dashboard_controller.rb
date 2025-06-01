class DashboardController < ApplicationController
  def index
    @tasks = Task.kept.includes(:agent, :project).order(created_at: :desc)
    @task = Task.new
    @task.agent_id = cookies[:preferred_agent_id] if cookies[:preferred_agent_id].present?
    @task.project_id = cookies[:preferred_project_id] if cookies[:preferred_project_id].present?
    @projects = Project.kept
    @agents = Agent.kept
  end
end
