require "open3"

class RepositoryDownloadsController < ApplicationController
  before_action :set_task

  def show
    Rails.logger.info "Repository download show action started for task #{@task.id}"
    project = @task.project
    if project.repository_url.blank? && project.repo_path.blank?
      Rails.logger.info "No repository configured - redirecting"
      redirect_to @task, alert: "No repository configured for this project"
      return
    end

    repo_path = determine_repo_path
    Rails.logger.info "Determined repo_path: #{repo_path.inspect}"

    unless repo_path && File.exist?(repo_path)
      Rails.logger.info "Repository not available - path doesn't exist: #{repo_path.inspect}"
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
    Rails.logger.info "Repository download: task_id=#{params[:task_id]}, task.user_id=#{@task.user_id}, current_user_id=#{Current.user&.id}"
    unless @task.user == Current.user
      redirect_to @task, alert: "You don't have permission to download this repository"
      false
    end
  end

  def determine_repo_path
    project = @task.project

    # Try to extract from Docker volume first (this is the primary method)
    if extract_from_docker_volume
      Rails.root.join("tmp", "task-#{@task.id}-workspace").to_s
    elsif project.repo_path.present?
      # Local repository path (for development/testing)
      project.repo_path
    else
      # No valid repository source found
      Rails.logger.warn "No valid repository source found for task #{@task.id}"
      nil
    end
  end

  def extract_from_docker_volume
    Rails.logger.info "Attempting to extract from Docker volume for task #{@task.id}"
    workplace_mount = @task.workplace_mount
    unless workplace_mount
      Rails.logger.info "No workplace mount found for task #{@task.id}"
      return false
    end

    volume_name = workplace_mount.volume_name
    unless volume_name
      Rails.logger.info "No volume name found for workplace mount"
      return false
    end
    Rails.logger.info "Found volume: #{volume_name}"

    # Create extraction directory
    extract_dir = Rails.root.join("tmp", "task-#{@task.id}-workspace")
    FileUtils.rm_rf(extract_dir)
    FileUtils.mkdir_p(extract_dir)

    # Account for project's repo_path within the volume
    project = @task.project
    source_path = if project.repo_path.present?
      repo_subpath = project.repo_path.sub(/^\//, "")
      "/workspace/#{repo_subpath}"
    else
      "/workspace"
    end

    # Create a temporary container to extract files from the volume
    container = nil
    begin
      Rails.logger.info "Creating temporary container to extract from volume"
      container = Docker::Container.create(
        "Image" => "alpine",
        "Cmd" => [ "sh", "-c", "sleep 1" ],
        "HostConfig" => {
          "Binds" => [ "#{volume_name}:/workspace" ]
        }
      )

      Rails.logger.info "Starting container"
      container.start

      # Create a tar file from the source path
      tar_file = extract_dir.join("workspace.tar")
      Rails.logger.info "Extracting #{source_path} from container to #{tar_file}"

      File.open(tar_file, "wb") do |f|
        container.archive_out(source_path) do |chunk|
          f.write(chunk)
        end
      end

      # Extract the tar file
      Rails.logger.info "Extracting tar file to #{extract_dir}"
      stdout, stderr, status = Open3.capture3("tar", "-xf", tar_file.to_s, "-C", extract_dir.to_s, "--strip-components=1")
      unless status.success?
        Rails.logger.error "Failed to extract tar file: #{stderr}"
        return false
      end

      # Clean up tar file
      FileUtils.rm(tar_file)

      # Check if extraction was successful
      success = File.exist?(extract_dir) && !Dir.empty?(extract_dir)
      Rails.logger.info "Extraction successful: #{success}, directory exists: #{File.exist?(extract_dir)}, directory empty: #{Dir.empty?(extract_dir) if File.exist?(extract_dir)}"
      success
    rescue => e
      Rails.logger.error "Failed to extract Docker volume: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    ensure
      # Clean up temporary container
      if container
        Rails.logger.info "Cleaning up temporary container"
        container.delete(force: true) rescue nil
      end
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
