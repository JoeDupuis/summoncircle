require "docker"

class ClaudeOauth
  OAUTH_IMAGE = "claude_oauth:latest"
  VOLUME_NAME = "claude_config"

  def initialize(agent)
    @agent = agent
    set_docker_host(@agent.docker_host)
  end

  def login_start
    ensure_volume_exists
    ensure_image_exists

    container = create_oauth_container(
      [ "/home/claude/login_start.rb" ]
    )

    container.start
    wait_result = container.wait(30)
    logs = container.logs(stdout: true, stderr: true)
    output = clean_logs(logs)

    if wait_result["StatusCode"] == 0
      # Extract the OAuth URL from the output
      url_match = output.match(/https:\/\/claude\.ai\/oauth\/authorize\?[^\s]+/)
      url_match ? url_match[0] : nil
    else
      raise "Failed to generate OAuth URL: #{output}"
    end
  ensure
    container&.delete(force: true) if defined?(container)
    restore_docker_config
  end

  def login_finish(authorization_code)
    ensure_volume_exists
    ensure_image_exists

    container = create_oauth_container(
      [ "/home/claude/login_finish.rb", authorization_code ]
    )

    container.start
    wait_result = container.wait(60)
    logs = container.logs(stdout: true, stderr: true)
    output = clean_logs(logs)

    if wait_result["StatusCode"] == 0
      # Check if credentials were saved
      check_credentials_exist
    else
      raise "Failed to complete OAuth login: #{output}"
    end
  ensure
    container&.delete(force: true) if defined?(container)
    restore_docker_config
  end

  def refresh_token
    ensure_volume_exists
    ensure_image_exists

    container = create_oauth_container(
      [ "/home/claude/refresh_token.rb", "--force" ]
    )

    container.start
    wait_result = container.wait(60)
    logs = container.logs(stdout: true, stderr: true)
    output = clean_logs(logs)

    if wait_result["StatusCode"] == 0
      output.include?("Token refreshed successfully!")
    else
      raise "Failed to refresh token: #{output}"
    end
  ensure
    container&.delete(force: true) if defined?(container)
    restore_docker_config
  end

  def check_credentials_exist
    container = Docker::Container.create(
      "Image" => OAUTH_IMAGE,
      "Entrypoint" => [ "/bin/sh" ],
      "Cmd" => [ "-c", "[ -f /home/claude/.claude/.credentials.json ] && echo 'yes' || echo 'no'" ],
      "User" => @agent.user_id.to_s,
      "HostConfig" => {
        "Binds" => [ "#{VOLUME_NAME}:/home/claude/.claude" ]
      }
    )

    container.start
    wait_result = container.wait(10)
    logs = container.logs(stdout: true, stderr: true)
    output = clean_logs(logs).strip

    output == "yes"
  ensure
    container&.delete(force: true) if defined?(container)
  end

  def get_token_expiry
    return nil unless check_credentials_exist

    container = Docker::Container.create(
      "Image" => OAUTH_IMAGE,
      "Entrypoint" => [ "/bin/sh" ],
      "Cmd" => [ "-c", "cat /home/claude/.claude/.credentials.json" ],
      "User" => @agent.user_id.to_s,
      "HostConfig" => {
        "Binds" => [ "#{VOLUME_NAME}:/home/claude/.claude" ]
      }
    )

    container.start
    wait_result = container.wait(10)
    logs = container.logs(stdout: true, stderr: true)
    output = clean_logs(logs).strip

    if wait_result["StatusCode"] == 0 && output.present?
      begin
        data = JSON.parse(output)
        # The credentials are nested under claudeAiOauth key
        oauth_data = data['claudeAiOauth'] || data
        expiry_timestamp = oauth_data['expiresAt'] || oauth_data['expires_at']
        
        if expiry_timestamp && expiry_timestamp.is_a?(Numeric)
          Time.at(expiry_timestamp / 1000)
        else
          nil
        end
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse OAuth credentials JSON: #{e.message}"
        nil
      end
    else
      nil
    end
  rescue => e
    Rails.logger.error "Failed to get token expiry: #{e.message}"
    nil
  ensure
    container&.delete(force: true) if defined?(container)
  end

  private

  def create_oauth_container(command)
    Docker::Container.create(
      "Image" => OAUTH_IMAGE,
      "Entrypoint" => [ "ruby" ],
      "Cmd" => command,
      "User" => @agent.user_id.to_s,
      "HostConfig" => {
        "Binds" => [ "#{VOLUME_NAME}:/home/claude/.claude" ]
      }
    )
  end

  def ensure_volume_exists
    volumes = Docker::Volume.all
    unless volumes.any? { |v| v.info["Name"] == VOLUME_NAME }
      Docker::Volume.create(VOLUME_NAME)
    end
  end

  def ensure_image_exists
    unless Docker::Image.exist?(OAUTH_IMAGE)
      raise "OAuth Docker image not found. Please build it using the claude_oauth repository."
    end
  rescue Docker::Error::NotFoundError
    raise "OAuth Docker image not found. Please build it using the claude_oauth repository."
  end

  def clean_logs(logs)
    logs.gsub(/^.{8}/m, "").force_encoding("UTF-8").scrub.strip
  end

  def set_docker_host(docker_host)
    @original_docker_url = Docker.url
    @original_docker_options = Docker.options

    return unless docker_host.present?

    Docker.url = docker_host
    Docker.options = {
      read_timeout: 600,
      write_timeout: 600,
      connect_timeout: 60
    }
  end

  def restore_docker_config
    Docker.url = @original_docker_url if @original_docker_url
    Docker.options = @original_docker_options if @original_docker_options
  end
end
