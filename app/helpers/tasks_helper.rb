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
end
