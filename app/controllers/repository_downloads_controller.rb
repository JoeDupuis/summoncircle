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

    # Create extraction directory - use sanitized task ID
    # Brakeman: Safe - task_id is sanitized to integer string
    task_id = @task.id.to_i.to_s # Ensure it's a clean integer string
    extract_dir = Rails.root.join("tmp", "task-#{task_id}-workspace")
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

      # Extract the tar file using rubygem tar reader (safer than system call)
      Rails.logger.info "Extracting tar file to #{extract_dir}"
      begin
        require "rubygems/package"
        File.open(tar_file, "rb") do |file|
          Gem::Package::TarReader.new(file) do |tar|
            tar.each do |entry|
              if entry.file?
                # Strip first directory component if present
                dest_path = entry.full_name.split("/")[1..-1].join("/")
                dest_path = entry.full_name if dest_path.empty?

                dest_file = File.join(extract_dir, dest_path)
                FileUtils.mkdir_p(File.dirname(dest_file))

                File.open(dest_file, "wb") do |f|
                  f.write(entry.read)
                end

                # Preserve file permissions
                File.chmod(entry.header.mode, dest_file)
              elsif entry.directory?
                # Strip first directory component if present
                dest_path = entry.full_name.split("/")[1..-1].join("/")
                next if dest_path.empty?

                dest_dir = File.join(extract_dir, dest_path)
                FileUtils.mkdir_p(dest_dir)
              end
            end
          end
        end
      rescue => e
        Rails.logger.error "Failed to extract tar file: #{e.message}"
        return false
      ensure
        # Clean up tar file
        FileUtils.rm(tar_file) if File.exist?(tar_file)
      end

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
    require "zip"
    archive_path = Rails.root.join("tmp", "#{SecureRandom.hex(8)}.zip")

    Zip::File.open(archive_path, Zip::File::CREATE) do |zipfile|
      Dir.glob(File.join(repo_path, "**", "*")).each do |file|
        # Skip directories, they'll be created automatically
        next if File.directory?(file)

        # Calculate the relative path for the zip entry
        relative_path = file.sub("#{repo_path}/", "")

        zipfile.add(relative_path, file)
      end
    end

    archive_path.to_s
  end
end
