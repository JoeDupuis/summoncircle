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

    send_file archive_path,
              filename: "#{@task.description.parameterize}-#{project.name.parameterize}-repository.tar",
              type: "application/x-tar",
              disposition: "attachment"
  ensure
    File.delete(archive_path) if archive_path && File.exist?(archive_path)
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

      # Extract tar file from the source path
      Rails.logger.info "Extracting #{source_path} from container to #{tar_file}"

      File.open(tar_file, "wb") do |f|
        container.archive_out(source_path) do |chunk|
          f.write(chunk)
        end
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
