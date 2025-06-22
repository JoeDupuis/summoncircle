class DockerGitCommand
  attr_reader :task, :command, :error_message, :return_logs, :working_dir, :skip_repo_path

  def initialize(task:, command:, error_message:, return_logs: false, working_dir: nil, skip_repo_path: false)
    @task = task
    @command = command
    @error_message = error_message
    @return_logs = return_logs
    @working_dir = working_dir
    @skip_repo_path = skip_repo_path
  end

  def execute
    container_config = build_container_config
    container_config = setup_git_credentials(container_config, task.user, task.project.repository_url)

    git_container = Docker::Container.create(container_config)
    git_container.start

    # Setup SSH key if needed for SSH URLs
    if task.project.repository_url&.match?(/\Agit@|ssh:\/\//)
      setup_ssh_key_in_container(git_container, task)
    end

    wait_result = git_container.wait(300)
    logs = git_container.logs(stdout: true, stderr: true)
    clean_logs = logs.dup.force_encoding("UTF-8").scrub.gsub(/^.{8}/m, "").strip
    exit_code = wait_result["StatusCode"] if wait_result.is_a?(Hash)

    if exit_code && exit_code != 0
      enhanced_error = enhance_git_error_message(clean_logs, task, command)
      raise enhanced_error
    end

    return_logs ? clean_logs : nil
  rescue => e
    raise "Git operation error: #{e.message} (#{e.class})"
  ensure
    git_container&.delete(force: true) if defined?(git_container)
  end

  private

  def build_container_config
    git_working_dir = calculate_working_directory
    
    {
      "Image" => task.agent.docker_image,
      "Entrypoint" => [ "sh" ],
      "Cmd" => [ "-c", command ],
      "WorkingDir" => git_working_dir,
      "User" => task.agent.user_id.to_s,
      "Env" => task.agent.env_strings + task.project.secrets.map { |s| "#{s.key}=#{s.value}" },
      "HostConfig" => {
        "Binds" => task.volume_mounts.includes(:volume).map(&:bind_string)
      }
    }
  end

  def calculate_working_directory
    repo_path = task.project.repo_path.presence || ""
    work_dir = working_dir || task.workplace_mount.container_path
    
    if skip_repo_path
      work_dir
    else
      File.join([ work_dir, repo_path.presence&.sub(/^\//, "") ].compact)
    end
  end

  def setup_git_credentials(container_config, user, repository_url)
    platform = git_platform_from_url(repository_url)
    return container_config unless platform

    platform_config = credentials_for(user, platform)
    return container_config unless platform_config

    container_config["Env"] ||= []
    container_config["Env"] << "#{platform_config[:env_var]}=#{platform_config[:token]}"
    container_config["Env"] << "GIT_ASKPASS=/tmp/git-askpass.sh"

    container_config["Cmd"] = wrap_with_credential_setup(container_config["Cmd"], platform_config)
    container_config
  end

  def setup_ssh_key_in_container(container, task)
    agent = task.agent
    user = task.user

    return unless user.ssh_key.present? && agent.ssh_mount_path.present?

    encoded_content = Base64.strict_encode64(user.ssh_key)
    target_dir = File.dirname(agent.ssh_mount_path)

    # Create .ssh directory
    container.exec([ "mkdir", "-p", target_dir ])

    # Write SSH key
    container.exec([ "sh", "-c", "echo '#{encoded_content}' | base64 -d > #{agent.ssh_mount_path}" ])

    # Set permissions
    container.exec([ "chmod", "600", agent.ssh_mount_path ])
    container.exec([ "chmod", "700", target_dir ])
  rescue => e
    Rails.logger.error "Failed to setup SSH key in container: #{e.message}"
  end

  def enhance_git_error_message(original_error, task, command)
    if original_error.include?("Permission denied (publickey)") || original_error.include?("Could not read from remote repository")
      user = task.user
      agent = task.agent

      if task.project.repository_url&.match?(/\Agit@|ssh:\/\//)
        if user.ssh_key.blank?
          return "SSH authentication failed: No SSH key configured for your user account. Please add an SSH key in your user settings to access this repository."
        elsif agent.ssh_mount_path.blank?
          return "SSH authentication failed: Agent is missing SSH mount path configuration. Please configure the agent's SSH mount path."
        else
          return "SSH authentication failed: The SSH key may not have access to this repository. Please ensure your SSH key is added to the repository's deploy keys or your GitHub/GitLab account."
        end
      end
    end

    "#{original_error}"
  end

  def git_platform_from_url(url)
    return nil unless url.present?

    case url
    when /github\.com/
      :github
    else
      nil
    end
  end

  def credentials_for(user, platform)
    case platform
    when :github
      return nil unless user&.github_token.present?
      {
        username: "x-access-token",
        env_var: "GITHUB_TOKEN",
        token: user.github_token
      }
    else
      nil
    end
  end

  def wrap_with_credential_setup(original_cmd, platform_config)
    askpass_script = generate_askpass_script(platform_config)

    setup_script = <<~BASH.strip
      echo '#{askpass_script}' > /tmp/git-askpass.sh && \
      chmod +x /tmp/git-askpass.sh
    BASH

    if original_cmd.is_a?(Array) && original_cmd[0] == "-c"
      [ "-c", "#{setup_script} && #{original_cmd[1]}" ]
    else
      [ "-c", "#{setup_script} && #{Array(original_cmd).join(' ')}" ]
    end
  end

  def generate_askpass_script(platform_config)
    <<~BASH
      #!/bin/sh
      case "$1" in
        Username*) echo "#{platform_config[:username]}" ;;
        Password*) echo "$#{platform_config[:env_var]}" ;;
      esac
    BASH
  end
end