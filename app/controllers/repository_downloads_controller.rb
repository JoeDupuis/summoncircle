class RepositoryDownloadsController < ApplicationController
  before_action :set_task

  def show
    project = @task.project
    if project.repository_url.blank? && project.repo_path.blank?
      redirect_to @task, alert: "No repository configured for this project"
      return
    end

    repo_path = determine_repo_path
    unless File.exist?(repo_path)
      redirect_to @task, alert: "Repository not found at configured path"
      return
    end

    archive_path = create_repository_archive(repo_path)

    send_file archive_path,
              filename: "#{@task.description.parameterize}-#{project.name.parameterize}-repository.zip",
              type: "application/zip",
              disposition: "attachment"
  ensure
    File.delete(archive_path) if archive_path && File.exist?(archive_path)
  end

  private

  def set_task
    @task = Task.find(params[:task_id])
    unless @task.user == Current.user
      raise ActiveRecord::RecordNotFound
    end
  end

  def determine_repo_path
    project = @task.project

    # For now, just use the project's repo_path or a temp directory
    # TODO: Implement proper Docker volume inspection to get the actual task workspace
    if project.repo_path.present?
      project.repo_path
    elsif project.repository_url.present?
      # This is a placeholder - in reality, we'd need to extract from Docker volume
      Rails.root.join("tmp", "repos", "task-#{@task.id}").to_s
    end
  end

  def create_repository_archive(repo_path)
    archive_path = Rails.root.join("tmp", "#{SecureRandom.hex(8)}.zip")

    Dir.chdir(File.dirname(repo_path)) do
      system("zip", "-r", archive_path.to_s, File.basename(repo_path), "-x", "*.git*")
    end

    archive_path.to_s
  end
end
