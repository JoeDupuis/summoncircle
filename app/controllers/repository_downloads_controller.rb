class RepositoryDownloadsController < ApplicationController
  before_action :set_task

  def show
    project = @task.project
    if project.repository_url.blank? && project.repo_path.blank?
      redirect_to @task, alert: "No repository configured for this project"
      return
    end

    archive_path = extract_repository_as_tar
    unless archive_path
      redirect_to @task, alert: "Repository not available for download"
      return
    end

    # Read the file into memory before sending
    tar_data = File.read(archive_path, mode: "rb")

    send_data tar_data,
              filename: "#{@task.description.parameterize}-#{project.name.parameterize}-repository.tar",
              type: "application/x-tar",
              disposition: "attachment"
  ensure
    # Clean up the temporary file
    if archive_path && File.exist?(archive_path)
      File.delete(archive_path)
    end
  end

  private

  def set_task
    @task = Task.find(params[:task_id])
    unless @task.user == Current.user
      redirect_to @task, alert: "You don't have permission to download this repository"
      false
    end
  end

  def extract_repository_as_tar
    workplace_mount = @task.workplace_mount
    unless workplace_mount
      return nil
    end

    volume_name = workplace_mount.volume_name
    unless volume_name
      return nil
    end

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
      container = Docker::Container.create(
        "Image" => "alpine",
        "Cmd" => [ "sh", "-c", "sleep 1" ],
        "HostConfig" => {
          "Binds" => [ "#{volume_name}:/workspace" ]
        }
      )

      container.start

      # First, check if the path exists in the container
      begin
        # Check if the specific path exists
        path_check = container.exec([ "test", "-e", source_path ])
        if path_check[2] != 0
          return nil
        end
      rescue => e
        # Path check failed
      end

      # Extract tar file from the source path

      begin
        File.open(tar_file, "wb") do |f|
          container.archive_out(source_path) do |chunk|
            f.write(chunk)
          end
        end
      rescue Docker::Error::NotFoundError => e
        return nil
      rescue => e
        raise
      end

      # Return the tar file path if successful
      if File.exist?(tar_file) && File.size(tar_file) > 0
        tar_file.to_s
      else
        FileUtils.rm(tar_file) if File.exist?(tar_file)
        nil
      end
    rescue => e
      FileUtils.rm(tar_file) if File.exist?(tar_file)
      nil
    ensure
      # Clean up temporary container
      if container
        container.delete(force: true) rescue nil
      end
    end
  end
end
