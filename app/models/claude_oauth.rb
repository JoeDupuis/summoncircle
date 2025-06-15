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
    Rails.logger.info "ClaudeOauth#get_token_expiry: Starting token expiry check for agent #{@agent.id}"
    
    credentials_exist = check_credentials_exist
    Rails.logger.info "ClaudeOauth#get_token_expiry: Credentials exist? #{credentials_exist}"
    return nil unless credentials_exist

    container = Docker::Container.create(
      "Image" => OAUTH_IMAGE,
      "Entrypoint" => [ "ruby" ],
      "Cmd" => [ "-e", "require 'json'; data = JSON.parse(File.read('/home/claude/.claude/.credentials.json')); puts data['expiresAt']" ],
      "User" => @agent.user_id.to_s,
      "HostConfig" => {
        "Binds" => [ "#{VOLUME_NAME}:/home/claude/.claude" ]
      }
    )

    container.start
    wait_result = container.wait(10)
    logs = container.logs(stdout: true, stderr: true)
    raw_logs = logs
    output = clean_logs(logs).strip
    
    Rails.logger.info "ClaudeOauth#get_token_expiry: Container exit code: #{wait_result['StatusCode']}"
    Rails.logger.info "ClaudeOauth#get_token_expiry: Raw logs: #{raw_logs.inspect}"
    Rails.logger.info "ClaudeOauth#get_token_expiry: Cleaned output: '#{output}'"
    Rails.logger.info "ClaudeOauth#get_token_expiry: Output matches digits? #{output.match?(/^\d+$/)}"

    if wait_result["StatusCode"] == 0 && output.match?(/^\d+$/)
      expiry_time = Time.at(output.to_i / 1000)
      Rails.logger.info "ClaudeOauth#get_token_expiry: Parsed expiry time: #{expiry_time}"
      expiry_time
    else
      Rails.logger.warn "ClaudeOauth#get_token_expiry: Failed to parse expiry. Exit code: #{wait_result['StatusCode']}, Output: '#{output}'"
      nil
    end
  rescue => e
    Rails.logger.error "ClaudeOauth#get_token_expiry: Exception occurred: #{e.class} - #{e.message}"
    Rails.logger.error "ClaudeOauth#get_token_expiry: Backtrace: #{e.backtrace.first(5).join("\n")}"
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
