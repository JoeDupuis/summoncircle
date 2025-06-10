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
  end
  dev_user.update!(git_config: <<~CONFIG)
    [user]
      name = Dev User
      email = dev@example.com
  CONFIG

  standard_user = User.find_or_create_by!(email_address: "user@example.com") do |user|
    user.password = "password"
    user.password_confirmation = "password"
    user.role = "standard"
  end
  standard_user.update!(git_config: <<~CONFIG)
    [user]
      name = Standard User
      email = user@example.com
  CONFIG

  claude_agent = Agent.find_or_create_by!(name: "Claude") do |agent|
    agent.docker_image = "claude_max:latest"
    agent.workplace_path = "/workspace"
    agent.start_arguments = [ "--dangerously-skip-permissions", "--model", "sonnet", "-p", "{PROMPT}" ]
    agent.continue_arguments = [ "-c", "--dangerously-skip-permissions", "--model", "sonnet", "-p", "{PROMPT}" ]
  end
  claude_agent.update!(
    home_path: "/home/claude",
    instructions_mount_path: "/home/claude/.claude/CLAUDE.md",
    mcp_sse_endpoint: "http://host.docker.internal:3000"
  )

  Volume.find_or_create_by!(agent: claude_agent, name: "home") do |volume|
    volume.path = "/home/claude"
  end

  claude_json_agent = Agent.find_or_create_by!(name: "Claude Json") do |agent|
    agent.docker_image = "claude_max:latest"
    agent.workplace_path = "/workspace"
    agent.start_arguments = [ "--dangerously-skip-permissions", "--model", "sonnet", "--output-format", "json", "--verbose", "-p", "{PROMPT}" ]
    agent.continue_arguments = [ "-c", "--dangerously-skip-permissions", "--model", "sonnet", "--output-format", "json", "--verbose", "-p", "{PROMPT}" ]
    agent.log_processor = "ClaudeJson"
  end
  claude_json_agent.update!(
    home_path: "/home/claude",
    instructions_mount_path: "/home/claude/.claude/CLAUDE.md",
    mcp_sse_endpoint: "http://host.docker.internal:3000"
  )

  Volume.find_or_create_by!(agent: claude_json_agent, name: "home") do |volume|
    volume.path = "/home/claude"
  end

  claude_streaming_agent = Agent.find_or_create_by!(name: "Claude Streaming") do |agent|
    agent.docker_image = "claude_max:latest"
    agent.workplace_path = "/workspace"
    agent.start_arguments = [ "--dangerously-skip-permissions", "--model", "sonnet", "--output-format", "stream-json", "--verbose", "-p", "{PROMPT}" ]
    agent.continue_arguments = [ "-c", "--dangerously-skip-permissions", "--model", "sonnet", "--output-format", "stream-json", "--verbose", "-p", "{PROMPT}" ]
    agent.log_processor = "ClaudeStreamingJson"
  end
  claude_streaming_agent.update!(
    home_path: "/home/claude",
    instructions_mount_path: "/home/claude/.claude/CLAUDE.md",
    mcp_sse_endpoint: "http://host.docker.internal:3000"
  )

  Volume.find_or_create_by!(agent: claude_streaming_agent, name: "home") do |volume|
    volume.path = "/home/claude"
  end

  Project.find_or_create_by!(name: "SummonCircle") do |project|
    project.repository_url = "https://github.com/JoeDupuis/summoncircle"
  end

  Project.find_or_create_by!(name: "Shenanigans") do |project|
    project.repository_url = "https://github.com/JoeDupuis/shenanigans"
  end
end