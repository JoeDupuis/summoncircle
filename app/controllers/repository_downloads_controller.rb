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

    archive_path = extract_repository_as_tar
    unless archive_path
      Rails.logger.info "Repository not available for download"
      redirect_to @task, alert: "Repository not available for download"
      return
    end

    Rails.logger.info "Sending file: #{archive_path}, size: #{File.size(archive_path)} bytes"

    # Read the file into memory before sending
    tar_data = File.read(archive_path, mode: "rb")

    send_data tar_data,
              filename: "#{@task.description.parameterize}-#{project.name.parameterize}-repository.tar",
              type: "application/x-tar",
              disposition: "attachment"
  ensure
    # Clean up the temporary file
    if archive_path && File.exist?(archive_path)
      Rails.logger.info "Cleaning up temporary file: #{archive_path}"
      File.delete(archive_path)
    end
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

  def extract_repository_as_tar
    Rails.logger.info "Attempting to extract repository as tar for task #{@task.id}"
    workplace_mount = @task.workplace_mount
    unless workplace_mount
      Rails.logger.info "No workplace mount found for task #{@task.id}"
      return nil
    end

    volume_name = workplace_mount.volume_name
    unless volume_name
      Rails.logger.info "No volume name found for workplace mount"
      return nil
    end
    Rails.logger.info "Found volume: #{volume_name}"

    # Account for project's repo_path within the volume
    project = @task.project
    source_path = if project.repo_path.present?
      repo_subpath = project.repo_path.sub(/^\//, "")
      "/workspace/#{repo_subpath}"
    else
      "/workspace"
    end

    # Create a temporary tar file
    tar_file = Rails.root.join("tmp", "#{SecureRandom.hex(8)}.tar")

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

      # First, check if the path exists in the container
      Rails.logger.info "Checking if path exists in container: #{source_path}"
      begin
        # Try to list the directory to see what's there
        check_result = container.exec([ "ls", "-la", "/workspace" ])
        Rails.logger.info "Contents of /workspace: #{check_result[0].join("\n")}"

        # Check if the specific path exists
        path_check = container.exec([ "test", "-e", source_path ])
        if path_check[2] != 0
          Rails.logger.error "Path does not exist in container: #{source_path}"
          Rails.logger.info "Checking parent directory..."
          parent_check = container.exec([ "ls", "-la", File.dirname(source_path) ])
          Rails.logger.info "Parent directory contents: #{parent_check[0].join("\n")}"
          return nil
        end
      rescue => e
        Rails.logger.error "Error checking path existence: #{e.message}"
      end

      # Extract tar file from the source path
      Rails.logger.info "Extracting #{source_path} from container to #{tar_file}"

      bytes_written = 0
      begin
        File.open(tar_file, "wb") do |f|
          container.archive_out(source_path) do |chunk|
            bytes_written += chunk.bytesize
            Rails.logger.info "Writing chunk: #{chunk.bytesize} bytes (total: #{bytes_written})"
            f.write(chunk)
          end
        end
        Rails.logger.info "Total bytes written to tar: #{bytes_written}"
      rescue Docker::Error::NotFoundError => e
        Rails.logger.error "Path not found in container: #{source_path} - #{e.message}"
        return nil
      rescue => e
        Rails.logger.error "Error during archive_out: #{e.class} - #{e.message}"
        raise
      end

      # Return the tar file path if successful
      if File.exist?(tar_file) && File.size(tar_file) > 0
        Rails.logger.info "Successfully created tar file: #{tar_file} (#{File.size(tar_file)} bytes)"
        tar_file.to_s
      else
        Rails.logger.error "Tar file creation failed or empty"
        FileUtils.rm(tar_file) if File.exist?(tar_file)
        nil
      end
    rescue => e
      Rails.logger.error "Failed to extract repository: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      FileUtils.rm(tar_file) if File.exist?(tar_file)
      nil
    ensure
      # Clean up temporary container
      if container
        Rails.logger.info "Cleaning up temporary container"
        container.delete(force: true) rescue nil
      end
    end
  end
end
