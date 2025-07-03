require "open3"

class DockerContainerBuilder
  def initialize(task)
    @task = task
  end

  def build_and_run
    return unless @task.project.dev_dockerfile_path.present?

    # Clean up any existing container first (without broadcasting)
    remove_existing_container(broadcast: false)

    image_name = "summoncircle/task-#{@task.id}-dev"

    container_name = "task-#{@task.id}-dev-container-#{SecureRandom.hex(4)}"

    # Extract files from the workspace volume to build
    temp_dir = Rails.root.join("tmp", "docker-build-#{@task.id}")
    FileUtils.mkdir_p(temp_dir)

    begin
      extract_workspace_files(temp_dir)
      image = build_docker_image(temp_dir, image_name)
      container = create_and_start_container(image_name, container_name)

      update_task_with_container_info(container, container_name, image)
      broadcast_docker_status
    ensure
      FileUtils.rm_rf(temp_dir) if temp_dir && Dir.exist?(temp_dir)
    end
  end

  def remove_existing_container(broadcast: true)
    return unless @task.container_id.present?

    begin
      container = Docker::Container.get(@task.container_id)
      container.stop(t: 5)
      container.delete(force: true)
    rescue Docker::Error::NotFoundError
      # Container already gone
    rescue => e
      Rails.logger.warn "Failed to remove old container: #{e.message}"
    end

    # Clear old container info but keep docker_image_id for cleanup tracking
    # Also preserve container_status if we're in the middle of building
    @task.update!(
      container_id: nil,
      container_name: nil,
      container_status: @task.container_status == "building" ? "building" : nil
    )
    broadcast_docker_status if broadcast
  end

  def remove_old_image(image_name)
    begin
      old_image = Docker::Image.get(image_name)
      old_image.remove(force: true)
    rescue Docker::Error::NotFoundError
      # Image doesn't exist, that's fine
    rescue => e
      Rails.logger.warn "Failed to remove old image: #{e.message}"
    end
  end

  private

  def extract_workspace_files(temp_dir)
    # Create a temporary container to copy files from the volume
    volume_name = @task.workplace_mount.volume_name
    copy_container = Docker::Container.create(
      "Image" => "alpine",
      "Cmd" => [ "sh", "-c", "sleep 1" ],
      "HostConfig" => {
        "Binds" => [ "#{volume_name}:/workspace" ]
      }
    )

    begin
      copy_container.start

      # Copy the entire workspace to temp directory
      tar_file = temp_dir.join("workspace.tar")
      File.open(tar_file, "wb") do |f|
        copy_container.archive_out("/workspace") do |chunk|
          f.write(chunk)
        end
      end

      # Extract the tar file safely using Open3
      stdout, stderr, status = Open3.capture3("tar", "-xf", tar_file.to_s, "-C", temp_dir.to_s)
      unless status.success?
        raise "Failed to extract tar file: #{stderr}"
      end
      FileUtils.rm(tar_file)
    ensure
      copy_container.delete(force: true) rescue nil
    end
  end

  def build_docker_image(temp_dir, image_name)
    # Now build from the extracted directory
    workspace_dir = temp_dir.join("workspace")
    dockerfile_path = workspace_dir.join(@task.project.dev_dockerfile_path)

    unless File.exist?(dockerfile_path)
      raise "Dockerfile not found at: #{@task.project.dev_dockerfile_path}"
    end

    # Build context is the workspace root (where repo is cloned)
    tar_stream = create_tar_stream_from_directory(workspace_dir, @task.project.dev_dockerfile_path)
    
    # Build with CONTAINER_PROXY_BASE_URL as build argument
    build_args = ENV.slice("CONTAINER_PROXY_BASE_URL")
    
    Docker::Image.build_from_tar(tar_stream, t: image_name, dockerfile: @task.project.dev_dockerfile_path, buildargs: build_args)
  end

  def create_and_start_container(image_name, container_name)
    binds = @task.volume_mounts.includes(:volume).map(&:bind_string)
    container_port = @task.project.dev_container_port || 3000

    container_config = {
      "name" => container_name,
      "Image" => image_name,
      "WorkingDir" => @task.agent.workplace_path,
      "Env" => @task.docker_env_strings,
      "ExposedPorts" => {
        "#{container_port}/tcp" => {}
      },
      "HostConfig" => {
        "Binds" => binds,
        "PublishAllPorts" => true
      }
    }

    container = Docker::Container.create(container_config)
    container.start
    container
  end

  def update_task_with_container_info(container, container_name, image)
    container_info = container.json

    @task.update!(
      container_id: container.id,
      container_name: container_name,
      container_status: container_info["State"]["Status"],
      docker_image_id: image.id
    )
  end

  def create_tar_stream_from_directory(dir, dockerfile_name = "Dockerfile")
    tar_stream = StringIO.new
    Gem::Package::TarWriter.new(tar_stream) do |tar|
      # Add all files from the directory
      Dir[File.join(dir, "**", "*")].each do |file|
        next if File.directory?(file)

        relative_path = Pathname.new(file).relative_path_from(dir).to_s

        # Skip files that shouldn't be in build context
        next if relative_path.start_with?(".git/")
        next if relative_path.include?("/.git/")

        stat = File.stat(file)
        mode = stat.mode

        tar.add_file(relative_path, mode) do |tf|
          File.open(file, "rb") { |f| tf.write(f.read) }
        end
      end
    end
    tar_stream.rewind
    tar_stream
  end

  def broadcast_docker_status
    Turbo::StreamsChannel.broadcast_replace_to(
      @task,
      target: "docker_controls",
      partial: "tasks/docker_controls",
      locals: { task: @task }
    )
  end
end
