# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

if Rails.env.development?
  dev_user = User.find_or_create_by!(email_address: "dev@example.com") do |user|
    user.password = "password"
    user.password_confirmation = "password"
    user.role = "admin"
    user.git_config = <<~CONFIG
      [user]
        name = Dev User
        email = dev@example.com
    CONFIG
  end

  if ENV["SEED_GITHUB_TOKEN"].present? && dev_user.github_token.blank?
    dev_user.update!(github_token: ENV["SEED_GITHUB_TOKEN"])
  end

  standard_user = User.find_or_create_by!(email_address: "user@example.com") do |user|
    user.password = "password"
    user.password_confirmation = "password"
    user.role = "standard"
    user.git_config = <<~CONFIG
      [user]
        name = Standard User
        email = user@example.com
    CONFIG
  end

  if ENV["SEED_GITHUB_TOKEN"].present? && standard_user.github_token.blank?
    standard_user.update!(github_token: ENV["SEED_GITHUB_TOKEN"])
  end

  claude_agent = Agent.find_or_create_by!(name: "Claude") do |agent|
    agent.docker_image = "joedupuis/claude_oauth:latest"
    agent.workplace_path = "/workspace"
    agent.home_path = "/home/claude"
    agent.instructions_mount_path = "/home/claude/.claude/CLAUDE.md"
    agent.ssh_mount_path = "/home/claude/.ssh/id_rsa"
    agent.mcp_sse_endpoint = "http://host.docker.internal:3000"
    agent.start_arguments = [ "--dangerously-skip-permissions", "--model", "sonnet", "-p", "{PROMPT}" ]
    agent.continue_arguments = [ "-c", "--dangerously-skip-permissions", "--model", "sonnet", "-p", "{PROMPT}" ]
  end

  Volume.find_or_create_by!(agent: claude_agent, name: "home") do |volume|
    volume.path = "/home/claude"
  end

  Volume.find_or_create_by!(agent: claude_agent, name: "claude_config") do |volume|
    volume.path = "/home/claude/.claude"
    volume.external = true
    volume.external_name = "claude_config"
  end

  Volume.find_or_create_by!(agent: claude_agent, name: "claude_projects") do |volume|
    volume.path = "/home/claude/.claude/projects"
  end

  ClaudeOauthSetting.find_or_create_by!(agent: claude_agent)

  claude_json_agent = Agent.find_or_create_by!(name: "Claude Json") do |agent|
    agent.docker_image = "joedupuis/claude_oauth:latest"
    agent.workplace_path = "/workspace"
    agent.home_path = "/home/claude"
    agent.instructions_mount_path = "/home/claude/.claude/CLAUDE.md"
    agent.ssh_mount_path = "/home/claude/.ssh/id_rsa"
    agent.mcp_sse_endpoint = "http://host.docker.internal:3000"
    agent.start_arguments = [ "--dangerously-skip-permissions", "--model", "sonnet", "--output-format", "json", "--verbose", "-p", "{PROMPT}" ]
    agent.continue_arguments = [ "-c", "--dangerously-skip-permissions", "--model", "sonnet", "--output-format", "json", "--verbose", "-p", "{PROMPT}" ]
    agent.log_processor = "ClaudeJson"
  end

  Volume.find_or_create_by!(agent: claude_json_agent, name: "home") do |volume|
    volume.path = "/home/claude"
  end

  Volume.find_or_create_by!(agent: claude_json_agent, name: "claude_config") do |volume|
    volume.path = "/home/claude/.claude"
    volume.external = true
    volume.external_name = "claude_config"
  end

  Volume.find_or_create_by!(agent: claude_json_agent, name: "claude_projects") do |volume|
    volume.path = "/home/claude/.claude/projects"
  end

  ClaudeOauthSetting.find_or_create_by!(agent: claude_json_agent)

  claude_streaming_agent = Agent.find_or_create_by!(name: "Claude Streaming") do |agent|
    agent.docker_image = "joedupuis/claude_oauth:latest"
    agent.workplace_path = "/workspace"
    agent.home_path = "/home/claude"
    agent.instructions_mount_path = "/home/claude/.claude/CLAUDE.md"
    agent.ssh_mount_path = "/home/claude/.ssh/id_rsa"
    agent.mcp_sse_endpoint = "http://host.docker.internal:3000"
    agent.start_arguments = [ "--dangerously-skip-permissions", "--model", "sonnet", "--output-format", "stream-json", "--verbose", "-p", "{PROMPT}" ]
    agent.continue_arguments = [ "-c", "--dangerously-skip-permissions", "--model", "sonnet", "--output-format", "stream-json", "--verbose", "-p", "{PROMPT}" ]
    agent.log_processor = "ClaudeStreamingJson"
  end

  Volume.find_or_create_by!(agent: claude_streaming_agent, name: "home") do |volume|
    volume.path = "/home/claude"
  end

  Volume.find_or_create_by!(agent: claude_streaming_agent, name: "claude_config") do |volume|
    volume.path = "/home/claude/.claude"
    volume.external = true
    volume.external_name = "claude_config"
  end

  Volume.find_or_create_by!(agent: claude_streaming_agent, name: "claude_projects") do |volume|
    volume.path = "/home/claude/.claude/projects"
  end

  ClaudeOauthSetting.find_or_create_by!(agent: claude_streaming_agent)

  Project.find_or_create_by!(name: "SummonCircle") do |project|
    project.repository_url = "https://github.com/JoeDupuis/summoncircle"
  end

  Project.find_or_create_by!(name: "Shenanigans") do |project|
    project.repository_url = "https://github.com/JoeDupuis/shenanigans"
  end

  Project.find_or_create_by!(name: "SSHenanigans") do |project|
    project.repository_url = "git@github.com:JoeDupuis/shenanigans.git"
  end
end

if Rails.env.production?
  admin_email = ENV.fetch("ADMIN_EMAIL", "admin@example.com")
  admin_password = ENV.fetch("ADMIN_PASSWORD", SecureRandom.alphanumeric(16))

  admin_user = User.find_or_create_by!(email_address: admin_email) do |user|
    user.password = admin_password
    user.password_confirmation = admin_password
    user.role = "admin"
  end

  if admin_user.persisted? && admin_user.created_at > 5.seconds.ago
    Rails.logger.info "Created admin user with email: #{admin_email} and password: #{admin_password}"
    puts "Created admin user with email: #{admin_email} and password: #{admin_password}"
  end

  mcp_endpoint = ENV.fetch("MCP_SSE_ENDPOINT", "http://host.docker.internal:3000")

  task_agent = Agent.find_or_create_by!(name: "Task namer") do |agent|
    agent.docker_image = "joedupuis/claude_oauth:latest"
    agent.workplace_path = "/workspace"
    agent.home_path = "/home/claude"
    agent.instructions_mount_path = "/home/claude/.claude/CLAUDE.md"
    agent.ssh_mount_path = "/home/claude/.ssh/id_rsa"
    agent.mcp_sse_endpoint = mcp_endpoint
    agent.start_arguments = [ "--dangerously-skip-permissions", "--model", "sonnet", "-p", "{PROMPT}" ]
    agent.continue_arguments = [ "-c", "--dangerously-skip-permissions", "--model", "sonnet", "-p", "{PROMPT}" ]
  end

  Volume.find_or_create_by!(agent: task_agent, name: "home") do |volume|
    volume.path = "/home/claude"
  end

  Volume.find_or_create_by!(agent: task_agent, name: "claude_projects") do |volume|
    volume.path = "/home/claude/.claude/projects"
  end

  sonnet_agent = Agent.find_or_create_by!(name: "Sonnet") do |agent|
    agent.docker_image = "joedupuis/claude_oauth:latest"
    agent.workplace_path = "/workspace"
    agent.home_path = "/home/claude"
    agent.instructions_mount_path = "/home/claude/.claude/CLAUDE.md"
    agent.ssh_mount_path = "/home/claude/.ssh/id_rsa"
    agent.mcp_sse_endpoint = mcp_endpoint
    agent.start_arguments = [ "--dangerously-skip-permissions", "--model", "sonnet", "--output-format", "stream-json", "--verbose", "-p", "{PROMPT}" ]
    agent.continue_arguments = [ "-c", "--dangerously-skip-permissions", "--model", "sonnet", "--output-format", "stream-json", "--verbose", "-p", "{PROMPT}" ]
    agent.log_processor = "ClaudeStreamingJson"
  end

  Volume.find_or_create_by!(agent: sonnet_agent, name: "home") do |volume|
    volume.path = "/home/claude"
  end

  Volume.find_or_create_by!(agent: sonnet_agent, name: "claude_projects") do |volume|
    volume.path = "/home/claude/.claude/projects"
  end

  opus_agent = Agent.find_or_create_by!(name: "Opus") do |agent|
    agent.docker_image = "joedupuis/claude_oauth:latest"
    agent.workplace_path = "/workspace"
    agent.home_path = "/home/claude"
    agent.instructions_mount_path = "/home/claude/.claude/CLAUDE.md"
    agent.ssh_mount_path = "/home/claude/.ssh/id_rsa"
    agent.mcp_sse_endpoint = mcp_endpoint
    agent.start_arguments = [ "--dangerously-skip-permissions", "--model", "opus", "--output-format", "stream-json", "--verbose", "-p", "{PROMPT}" ]
    agent.continue_arguments = [ "-c", "--dangerously-skip-permissions", "--model", "opus", "--output-format", "stream-json", "--verbose", "-p", "{PROMPT}" ]
    agent.log_processor = "ClaudeStreamingJson"
  end

  Volume.find_or_create_by!(agent: opus_agent, name: "home") do |volume|
    volume.path = "/home/claude"
  end

  Volume.find_or_create_by!(agent: opus_agent, name: "claude_projects") do |volume|
    volume.path = "/home/claude/.claude/projects"
  end

  if ENV["ANTHROPIC_API_KEY"].present?
    # When using API key, create secrets for each agent
    agents = [task_agent, sonnet_agent, opus_agent]
    agents.each do |agent|
      Secret.find_or_create_by!(secretable: agent, key: "ANTHROPIC_API_KEY") do |secret|
        secret.value = ENV["ANTHROPIC_API_KEY"]
      end
    end
    Rails.logger.info "Set ANTHROPIC_API_KEY as secret for all agents"
  else
    # When using OAuth, create claude_config volumes and OAuth settings
    Volume.find_or_create_by!(agent: task_agent, name: "claude_config") do |volume|
      volume.path = "/home/claude/.claude"
      volume.external = true
      volume.external_name = "claude_config"
    end

    Volume.find_or_create_by!(agent: sonnet_agent, name: "claude_config") do |volume|
      volume.path = "/home/claude/.claude"
      volume.external = true
      volume.external_name = "claude_config"
    end

    Volume.find_or_create_by!(agent: opus_agent, name: "claude_config") do |volume|
      volume.path = "/home/claude/.claude"
      volume.external = true
      volume.external_name = "claude_config"
    end

    ClaudeOauthSetting.find_or_create_by!(agent: task_agent)
    ClaudeOauthSetting.find_or_create_by!(agent: sonnet_agent)
    ClaudeOauthSetting.find_or_create_by!(agent: opus_agent)
  end
end