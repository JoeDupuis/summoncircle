module GitCredentialHelper
  GIT_ASKPASS_SCRIPT = <<~BASH
    #!/bin/sh
    case "$1" in
      Username*) echo "x-access-token" ;;
      Password*) echo "$GITHUB_TOKEN" ;;
    esac
  BASH

  def setup_git_credentials(container_config, github_token)
    return container_config unless github_token.present?

    container_config["Env"] ||= []
    container_config["Env"] << "GITHUB_TOKEN=#{github_token}"
    container_config["Env"] << "GIT_ASKPASS=/tmp/git-askpass.sh"

    container_config["Cmd"] = wrap_with_credential_setup(container_config["Cmd"])
    container_config
  end

  private

  def wrap_with_credential_setup(original_cmd)
    setup_script = <<~BASH.strip
      echo '#{GIT_ASKPASS_SCRIPT}' > /tmp/git-askpass.sh && \
      chmod +x /tmp/git-askpass.sh
    BASH

    if original_cmd.is_a?(Array) && original_cmd[0] == "-c"
      [ "-c", "#{setup_script} && #{original_cmd[1]}" ]
    else
      [ "-c", "#{setup_script} && #{Array(original_cmd).join(' ')}" ]
    end
  end
end
