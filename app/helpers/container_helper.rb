module ContainerHelper
  def container_state_for(task)
    return building_state if building_or_rebuilding?(task)
    
    verified_state(task)
  end

  def container_port_for(task)
    return nil unless task.container_id.present? && task.project.dev_container_port.present?
    return nil if building_or_rebuilding?(task)

    begin
      container = Docker::Container.get(task.container_id)
      port_mapping = container.json.dig("NetworkSettings", "Ports", "#{task.project.dev_container_port}/tcp")
      port_mapping&.first&.dig('HostPort')
    rescue Docker::Error::NotFoundError, StandardError
      nil
    end
  end

  private

  def building_or_rebuilding?(task)
    %w[building rebuilding].include?(task.container_status)
  end

  def building_state
    {
      container_exists: false,
      container_status: nil,
      port_info: nil
    }
  end

  def verified_state(task)
    return no_container_state unless task.container_id.present?

    begin
      container = Docker::Container.get(task.container_id)
      container_json = container.json
      current_status = container_json["State"]["Status"]

      update_task_status(task, current_status)

      {
        container_exists: true,
        container_status: current_status,
        port_info: extract_port_info(task, container_json)
      }
    rescue Docker::Error::NotFoundError
      clear_container_data(task)
      no_container_state
    rescue => e
      Rails.logger.warn "Failed to verify container state: #{e.message}"
      no_container_state
    end
  end

  def no_container_state
    {
      container_exists: false,
      container_status: nil,
      port_info: nil
    }
  end

  def update_task_status(task, current_status)
    if task.container_status != current_status
      task.update_column(:container_status, current_status)
    end
  end

  def extract_port_info(task, container_json)
    return nil unless task.project.dev_container_port.present?

    port_mapping = container_json.dig("NetworkSettings", "Ports", "#{task.project.dev_container_port}/tcp")
    port_mapping&.first&.dig('HostPort')
  end

  def clear_container_data(task)
    task.update_columns(
      container_id: nil,
      container_name: nil,
      container_status: nil,
      docker_image_id: nil
    )
  end
end