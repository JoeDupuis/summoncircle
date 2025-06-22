class RepositoryDownloadsController < ApplicationController
  before_action :set_task

  def show
    project = @task.project
    if project.repository_url.blank? && project.repo_path.blank?
      redirect_to @task, alert: "No repository configured for this project"
      return
    end

    repo_path = determine_repo_path

    unless repo_path && File.exist?(repo_path)
      redirect_to @task, alert: "Repository not available for download"
      return
    end

    archive_path = create_repository_archive(repo_path)

    Rails.logger.info "Sending file: #{archive_path}, size: #{File.size(archive_path)} bytes"

    data = File.read(archive_path)
    send_data data,
              filename: "#{@task.description.parameterize}-#{project.name.parameterize}-repository.zip",
              type: "application/zip",
              disposition: "attachment"
  ensure
    File.delete(archive_path) if archive_path && File.exist?(archive_path)
    # Clean up extracted workspace
    workspace_dir = Rails.root.join("tmp", "task-#{@task.id}-workspace")
    FileUtils.rm_rf(workspace_dir) if File.exist?(workspace_dir)
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

    # Try to extract from Docker volume first
    if extract_from_docker_volume
      Rails.root.join("tmp", "task-#{@task.id}-workspace").to_s
    elsif project.repo_path.present?
      project.repo_path
    elsif project.repository_url.present?
      Rails.root.join("tmp", "repos", "task-#{@task.id}").to_s
    end
  end

  def extract_from_docker_volume
    workplace_mount = @task.workplace_mount
    return false unless workplace_mount

    volume_name = workplace_mount.volume_name
    return false unless volume_name

    # Create extraction directory
    extract_dir = Rails.root.join("tmp", "task-#{@task.id}-workspace")
    FileUtils.rm_rf(extract_dir)
    FileUtils.mkdir_p(extract_dir)

    # Use Docker to copy files from volume to local directory
    # Create a temporary container with the volume mounted to copy files out
    temp_container = "extract-#{SecureRandom.hex(8)}"

    begin
      # Create container with volume mounted
      system("docker", "create", "--name", temp_container, "-v", "#{volume_name}:/source", "alpine", "true")

      # Copy files from volume to host
      system("docker", "cp", "#{temp_container}:/source/.", extract_dir.to_s)

      # Check if extraction was successful
      File.exist?(extract_dir) && !Dir.empty?(extract_dir)
    rescue => e
      Rails.logger.error "Failed to extract Docker volume: #{e.message}"
      false
    ensure
      # Clean up temporary container
      system("docker", "rm", temp_container) if temp_container
    end
  end

  def create_repository_archive(repo_path)
    archive_path = Rails.root.join("tmp", "#{SecureRandom.hex(8)}.zip")

    Dir.chdir(File.dirname(repo_path)) do
      system("zip", "-r", archive_path.to_s, File.basename(repo_path))
    end

    archive_path.to_s
  end
end
