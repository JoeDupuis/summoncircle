class DashboardController < ApplicationController
  def index
    @tasks = Task.kept.includes(:agent, :project).order(created_at: :desc)
    @task = Task.new
    @projects = Project.kept
    @agents = Agent.kept
  end
end
