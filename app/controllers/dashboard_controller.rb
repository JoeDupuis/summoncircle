class DashboardController < ApplicationController
  def index
    @tasks = Task.includes(:agent, :project).order(created_at: :desc)
    @task = Task.new
    @projects = Project.all
    @agents = Agent.all
  end
end
