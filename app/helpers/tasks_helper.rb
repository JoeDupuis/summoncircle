require "ostruct"

module TasksHelper
  def container_status_info(task)
    return OpenStruct.new(
      exists: false,
      status: task.container_status,
      port_info: nil
    ) if %w[building rebuilding removing].include?(task.container_status)

    return OpenStruct.new(
      exists: false,
      status: task.container_status,
      port_info: nil
    ) unless task.container_id.present?

    begin
      container = Docker::Container.get(task.container_id)
      container_json = container.json
      container_status = container_json["State"]["Status"]

      # Update task if status differs
      if task.container_status != container_status
        task.update_column(:container_status, container_status)
      end

      # Get port mapping
      port_info = nil
      if task.project.dev_container_port.present?
        port_mapping = container_json["NetworkSettings"]["Ports"]["#{task.project.dev_container_port}/tcp"]
        if port_mapping && port_mapping.first
          port_info = port_mapping.first["HostPort"]
        end
      end

      OpenStruct.new(
        exists: true,
        status: container_status,
        port_info: port_info
      )
    rescue Docker::Error::NotFoundError
      # Container doesn't exist in Docker, clear task data
      task.update_columns(
        container_id: nil,
        container_name: nil,
        container_status: nil,
        docker_image_id: nil
      )

      OpenStruct.new(
        exists: false,
        status: nil,
        port_info: nil
      )
    rescue => e
      Rails.logger.warn "Failed to verify container state: #{e.message}"

      OpenStruct.new(
        exists: false,
        status: task.container_status,
        port_info: nil
      )
    end
  end

  def task_proxy_path(task, path = nil)
    # Use proxy links only if CONTAINER_PROXY_LINKS is explicitly set
    use_proxy_links = ENV["CONTAINER_PROXY_LINKS"].present?
    
    unless use_proxy_links
      container_info = container_status_info(task)
      if container_info.port_info.present?
        base = "http://localhost:#{container_info.port_info}"
        return path ? "#{base}#{path}" : base
      else
        return "#" # No port available
      end
    end
    
    request = controller.request
    
    # Use CONTAINER_PROXY_BASE_URL if set, otherwise build from current request
    if ENV["CONTAINER_PROXY_BASE_URL"].present?
      base_url = ENV["CONTAINER_PROXY_BASE_URL"]
      # Ensure protocol is included
      base_url = "http://#{base_url}" unless base_url.match?(/^https?:\/\//)
      # Add task subdomain
      uri = URI.parse(base_url)
      host_parts = uri.host.split(".")
      host_parts.unshift("task-#{task.id}")
      uri.host = host_parts.join(".")
      base = uri.to_s
      return path ? "#{base}#{path}" : base
    else
      # Build from current request
      host_parts = request.host_with_port.split(".")
      
      # Replace the first part with task-{id} subdomain
      if host_parts.first.match?(/^task-\d+$/)
        host_parts[0] = "task-#{task.id}"
      else
        host_parts.unshift("task-#{task.id}")
      end
      
      base = "#{request.protocol}#{host_parts.join(".")}"
      return path ? "#{base}#{path}" : base
    end
  end
end
