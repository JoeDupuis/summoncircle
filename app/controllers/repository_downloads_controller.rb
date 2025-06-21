class RepositoryDownloadsController < ApplicationController
  before_action :set_task

  def show
    project = @task.project
    if project.repository_url.blank? && project.repo_path.blank?
      redirect_to @task, alert: "No repository configured for this project"
      return
    end

    repo_path = determine_repo_path

    # For development, create a dummy archive with a README explaining the limitation
    archive_path = if repo_path && File.exist?(repo_path)
      create_repository_archive(repo_path)
    else
      create_placeholder_archive
    end

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

  def create_placeholder_archive
    archive_path = Rails.root.join("tmp", "#{SecureRandom.hex(8)}.zip")
    temp_dir = Rails.root.join("tmp", "task-#{@task.id}-export")

    FileUtils.mkdir_p(temp_dir)

    # Create a README explaining the limitation
    File.write(temp_dir.join("README.txt"), <<~EOF)
      Task Repository Export - #{@task.description}
      =============================================

      This is a placeholder archive. The actual repository modifications made by
      the agent are stored in Docker volumes and are not directly accessible
      from the host filesystem.

      Task Details:
      - Task ID: #{@task.id}
      - Agent: #{@task.agent.name}
      - Project: #{@task.project.name}
      - Repository URL: #{@task.project.repository_url}

      To access the actual modified files, you would need to:
      1. Access the Docker container/volume where the agent ran
      2. Or implement Docker volume extraction functionality
    EOF

    # Create the zip
    Dir.chdir(Rails.root.join("tmp")) do
      system("zip", "-r", archive_path.to_s, "task-#{@task.id}-export")
    end

    # Clean up temp directory
    FileUtils.rm_rf(temp_dir)

    archive_path.to_s
  end
end
