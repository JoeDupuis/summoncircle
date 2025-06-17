module GitCredentialHelper
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

  private

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
