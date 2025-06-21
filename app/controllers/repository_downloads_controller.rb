class RepositoryDownloadsController < ApplicationController
  before_action :set_project

  def show
    if @project.repository_url.blank? && @project.repo_path.blank?
      redirect_to @project, alert: "No repository configured for this project"
      return
    end

    repo_path = determine_repo_path
    unless File.exist?(repo_path)
      redirect_to @project, alert: "Repository not found at configured path"
      return
    end

    archive_path = create_repository_archive(repo_path)

    send_file archive_path,
              filename: "#{@project.name.parameterize}-repository.zip",
              type: "application/zip",
              disposition: "attachment"
  ensure
    File.delete(archive_path) if archive_path && File.exist?(archive_path)
  end

  private

  def set_project
    @project = Current.user.projects.find(params[:project_id])
  end

  def determine_repo_path
    if @project.repo_path.present?
      @project.repo_path
    elsif @project.repository_url.present?
      Rails.root.join("tmp", "repos", @project.id.to_s).to_s
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
