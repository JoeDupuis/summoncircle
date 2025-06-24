class AutoTaskNamingJob < ApplicationJob
  queue_as :default

  def perform(task, prompt)
    Rails.logger.info "AutoTaskNamingJob starting for task #{task.id}"
    return unless task.user.auto_task_naming_agent

    naming_prompt = build_naming_prompt(prompt)
    naming_agent = task.user.auto_task_naming_agent
    Rails.logger.info "Using naming agent: #{naming_agent.name} (#{naming_agent.id})"

    begin
      generated_name = generate_name_with_docker(task, naming_agent, naming_prompt)

      if generated_name.present?
        task.update!(description: generated_name.strip)
        Rails.logger.info "Updated task #{task.id} with new description: #{generated_name.strip}"
      else
        Rails.logger.warn "Auto task naming returned empty result for task #{task.id}"
      end
    rescue => e
      Rails.logger.error "Auto task naming failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise # Re-raise the exception so the job fails properly
    end
  end

  private

  def build_naming_prompt(original_prompt)
    "I need a name for a task. Keep it short, but multiple words and spaces are allowed. It needs to describe the prompt. Answer with the name but nothing else. Your answer will be set as the name automatically. Here's the prompt: #{original_prompt}"
  end

  def generate_name_with_docker(task, agent, prompt)
    # Prepare Docker command
    command_template = agent.start_arguments
    command = command_template.map { |arg| arg.gsub("{PROMPT}", prompt) }
    
    # Get environment variables (agent + task user)
    user = task.user
    env_vars = agent.env_strings + user.env_strings
    
    # Get volume binds from agent
    binds = agent.volumes.map do |volume|
      if volume.external?
        "#{volume.external_name}:#{volume.path}"
      else
        # Generate volume name similar to VolumeMount
        volume_name = "summoncircle_#{volume.name}_volume_#{SecureRandom.uuid}"
        "#{volume_name}:#{volume.path}"
      end
    end
    
    # Create and run container
    container = Docker::Container.create(
      "Image" => agent.docker_image,
      "Cmd" => command,
      "Env" => env_vars,
      "User" => agent.user_id.to_s,
      "WorkingDir" => agent.workplace_path || "/workspace",
      "HostConfig" => {
        "Binds" => binds
      },
      "AttachStdout" => true,
      "AttachStderr" => true
    )
    
    container.start
    
    # Setup container files (git config, instructions, ssh key)
    setup_container_files(container, agent, user)
    
    # Attach and collect output
    output = ""
    container.attach { |stream, chunk| output += chunk if stream == :stdout }
    container.wait
    
    # Process output to extract the task name
    extract_task_name_from_output(output, agent)
  ensure
    container&.delete(force: true)
  end
  
  def setup_container_files(container, agent, user)
    
    if user.git_config.present? && agent.home_path.present?
      archive_file_to_container(container, user.git_config, File.join(agent.home_path, ".gitconfig"))
    end
    
    if user.instructions.present? && agent.instructions_mount_path.present?
      archive_file_to_container(container, user.instructions, agent.instructions_mount_path)
    end
    
    if user.ssh_key.present? && agent.ssh_mount_path.present?
      archive_file_to_container(container, user.ssh_key, agent.ssh_mount_path, 0o600)
    end
  end
  
  def archive_file_to_container(container, content, destination_path, permissions = 0o644)
    target_dir = File.dirname(destination_path)
    
    container.exec([ "mkdir", "-p", target_dir ])
    
    encoded_content = Base64.strict_encode64(content)
    container.exec([ "sh", "-c", "echo '#{encoded_content}' | base64 -d > #{destination_path}" ])
    container.exec([ "chmod", permissions.to_s(8), destination_path ])
  end

  def extract_task_name_from_output(output, agent)
    # Handle different log processor types
    case agent.log_processor
    when "ClaudeJson", "ClaudeStreamingJson"
      # Parse JSON response and extract text content
      begin
        json_lines = output.lines.select { |line| line.strip.start_with?("{") }
        json_lines.each do |line|
          data = JSON.parse(line)
          if data["type"] == "content" && data["content"].is_a?(Array)
            text_blocks = data["content"].select { |c| c["type"] == "text" }
            return text_blocks.first["text"] if text_blocks.any?
          end
        end
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse JSON output: #{e.message}"
      end
    else
      # For Text processor, just return the output
      output.strip
    end
  end
end
