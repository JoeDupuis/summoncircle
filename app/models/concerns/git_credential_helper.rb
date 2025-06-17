module GitCredentialHelper
  def setup_git_credentials(container_config, github_token)
    return container_config unless github_token.present?

    # For now, we only support GitHub. In the future, we could detect the platform
    # from the repository URL and use appropriate credentials
    platform_config = credentials_for_github(github_token)

    container_config["Env"] ||= []
    container_config["Env"] << "#{platform_config[:env_var]}=#{github_token}"
    container_config["Env"] << "GIT_ASKPASS=/tmp/git-askpass.sh"

    container_config["Cmd"] = wrap_with_credential_setup(container_config["Cmd"], platform_config)
    container_config
  end

  private

  # Platform detection - ready for future expansion
  def git_platform_from_url(url)
    return nil unless url.present?

    case url
    when /github\.com/
      :github
    when /gitlab\.com/
      :gitlab
    when /bitbucket\.org/
      :bitbucket
    else
      :generic
    end
  end

  # GitHub-specific credentials configuration
  def credentials_for_github(token)
    {
      username: "x-access-token",
      env_var: "GITHUB_TOKEN"
    }
  end

  # Future platform configurations can be added here:
  # def credentials_for_gitlab(token)
  #   {
  #     username: "oauth2",
  #     env_var: "GITLAB_TOKEN"
  #   }
  # end

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
