require "open3"

class DockerContainerBuilder
  include DockerStreamProcessor

  def initialize(task)
    @task = task
  end

  def build_and_run
    Rails.logger.info "[DockerContainerBuilder] Starting build_and_run for task #{@task.id}"

    unless @task.project.dev_dockerfile_path.present?
      Rails.logger.warn "[DockerContainerBuilder] No dockerfile path for task #{@task.id}"
      return
    end

    # Broadcast initial status
    Turbo::StreamsChannel.broadcast_append_to(
      "task_#{@task.id}_build_logs",
      target: "build-logs",
      html: "<div class='log-entry info'>Initializing build process...</div>"
    )

    # Clean up any existing container first (without broadcasting)
    remove_existing_container(broadcast: false)

    image_name = "summoncircle/task-#{@task.id}-dev"
    container_name = "task-#{@task.id}-dev-container-#{SecureRandom.hex(4)}"

    # Extract files from the workspace volume to build
    temp_dir = Rails.root.join("tmp", "docker-build-#{@task.id}")
    FileUtils.mkdir_p(temp_dir)

    begin
      Rails.logger.info "[DockerContainerBuilder] Extracting workspace files for task #{@task.id}"
      extract_workspace_files(temp_dir)

      Rails.logger.info "[DockerContainerBuilder] Building Docker image for task #{@task.id}"
      image = build_docker_image(temp_dir, image_name)

      Rails.logger.info "[DockerContainerBuilder] Creating container for task #{@task.id}"
      container = create_and_start_container(image_name, container_name)

      Rails.logger.info "[DockerContainerBuilder] Updating task info for task #{@task.id}"
      update_task_with_container_info(container, container_name, image)
      broadcast_docker_status

      # Broadcast completion
      Turbo::StreamsChannel.broadcast_append_to(
        "task_#{@task.id}_build_logs",
        target: "build-logs",
        html: "<div class='log-entry success'>Container started successfully!</div>"
      )
    rescue => e
      Rails.logger.error "[DockerContainerBuilder] Error for task #{@task.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Broadcast error
      Turbo::StreamsChannel.broadcast_append_to(
        "task_#{@task.id}_build_logs",
        target: "build-logs",
        html: "<div class='log-entry error'>Build failed: #{ERB::Util.html_escape(e.message)}</div>"
      )
      raise
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

    # Check if image already exists
    existing_image = nil
    begin
      existing_image = Docker::Image.get(image_name)
      Rails.logger.info "[DockerContainerBuilder] Found existing image: #{image_name}"

      Turbo::StreamsChannel.broadcast_append_to(
        "task_#{@task.id}_build_logs",
        target: "build-logs",
        html: "<div class='log-entry warning'>Found existing Docker image: #{image_name}</div>"
      )
    rescue Docker::Error::NotFoundError
      # Image doesn't exist, will need to build
      Rails.logger.info "[DockerContainerBuilder] No existing image found, will build: #{image_name}"
    end

    # Broadcast build start
    Turbo::StreamsChannel.broadcast_append_to(
      "task_#{@task.id}_build_logs",
      target: "build-logs",
      html: "<div class='log-entry info'>Preparing Docker build context...</div>"
    )

    # Build context is the workspace root (where repo is cloned)
    tar_stream = create_tar_stream_from_directory(workspace_dir, @task.project.dev_dockerfile_path)

    # Build with CONTAINER_PROXY_BASE_URL as build argument
    build_args = ENV.slice("CONTAINER_PROXY_BASE_URL").transform_values(&:to_s).to_json

    Turbo::StreamsChannel.broadcast_append_to(
      "task_#{@task.id}_build_logs",
      target: "build-logs",
      html: "<div class='log-entry info'>Starting Docker build...</div>"
    )

    # Stream build output with explicit streaming
    begin
      build_start = Time.current
      event_count = 0

      image = Docker::Image.build_from_tar(tar_stream,
        t: image_name,
        dockerfile: @task.project.dev_dockerfile_path,
        buildargs: build_args,
        nocache: false,
        rm: true
      ) do |event|
        event_count += 1
        # Process each event immediately
        stream_build_log(event)

        # Force flush to ensure immediate delivery
        Rails.logger.flush if Rails.logger.respond_to?(:flush)
      end

      build_duration = Time.current - build_start
      Rails.logger.info "[DockerContainerBuilder] Build completed in #{build_duration.round(2)}s with #{event_count} events"

      # Broadcast build summary
      Turbo::StreamsChannel.broadcast_append_to(
        "task_#{@task.id}_build_logs",
        target: "build-logs",
        html: "<div class='log-entry info'>Build completed in #{build_duration.round(2)} seconds</div>"
      )

      image
    rescue Docker::Error::UnexpectedResponseError => e
      Turbo::StreamsChannel.broadcast_append_to(
        "task_#{@task.id}_build_logs",
        target: "build-logs",
        html: "<div class='log-entry error'>Build error: #{ERB::Util.html_escape(e.message)}</div>"
      )
      raise
    end
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

    Rails.logger.info "[DockerContainerBuilder] Creating container with config: #{container_config.inspect}"

    container = Docker::Container.create(container_config)
    container.start

    # Wait a moment and check if container is still running
    sleep 0.5
    container.refresh!

    Rails.logger.info "[DockerContainerBuilder] Container status after start: #{container.info["State"]["Status"]}"

    container
  end

  def update_task_with_container_info(container, container_name, image)
    container_info = container.json

    Rails.logger.info "[DockerContainerBuilder] Container state: #{container_info["State"]["Status"]}"
    Rails.logger.info "[DockerContainerBuilder] Container running: #{container_info["State"]["Running"]}"

    @task.update!(
      container_id: container.id,
      container_name: container_name,
      container_status: container_info["State"]["Status"],
      docker_image_id: image.id
    )

    # If container exited immediately, log why
    if container_info["State"]["Status"] == "exited"
      exit_code = container_info["State"]["ExitCode"]
      Rails.logger.warn "[DockerContainerBuilder] Container exited with code #{exit_code}"

      # Get container logs
      logs = container.logs(stdout: true, stderr: true)
      processed_logs = process_docker_stream(logs)

      Turbo::StreamsChannel.broadcast_append_to(
        "task_#{@task.id}_build_logs",
        target: "build-logs",
        html: "<div class='log-entry error'>Container exited immediately with code #{exit_code}</div>"
      )

      if processed_logs.present?
        # Split logs into lines and format each one
        processed_logs.split("\n").each do |line|
          next if line.strip.empty?
          Turbo::StreamsChannel.broadcast_append_to(
            "task_#{@task.id}_build_logs",
            target: "build-logs",
            html: "<div class='log-entry'>#{ERB::Util.html_escape(line)}</div>"
          )
        end
      end
    end
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

  def stream_build_log(event)
    # Log timing for debugging
    Rails.logger.info "[BUILD LOG] Received at #{Time.current.strftime('%H:%M:%S.%L')}: #{event.truncate(100)}"

    # Parse the JSON event from Docker
    parsed_event = JSON.parse(event) rescue { "stream" => event }

    if parsed_event["stream"]
      # Format the log entry
      log_entry = parsed_event["stream"].strip
      return if log_entry.empty?

      # Determine the log entry type
      css_class = case log_entry
      when /error/i, /failed/i
                    "error"
      when /warning/i
                    "warning"
      when /step \d+\/\d+/i, /--->/i
                    "info"
      when /successfully/i, /complete/i
                    "success"
      else
                    ""
      end

      # Broadcast to the build logs stream
      Turbo::StreamsChannel.broadcast_append_to(
        "task_#{@task.id}_build_logs",
        target: "build-logs",
        html: "<div class='log-entry #{css_class}'>#{ERB::Util.html_escape(log_entry)}</div>"
      )
    elsif parsed_event["error"]
      # Handle errors
      error_message = parsed_event["error"]
      Turbo::StreamsChannel.broadcast_append_to(
        "task_#{@task.id}_build_logs",
        target: "build-logs",
        html: "<div class='log-entry error'>ERROR: #{ERB::Util.html_escape(error_message)}</div>"
      )
    elsif parsed_event["aux"] && parsed_event["aux"]["ID"]
      # Handle final build ID
      Turbo::StreamsChannel.broadcast_append_to(
        "task_#{@task.id}_build_logs",
        target: "build-logs",
        html: "<div class='log-entry success'>Build completed: #{ERB::Util.html_escape(parsed_event["aux"]["ID"])}</div>"
      )
    end
  end
end
