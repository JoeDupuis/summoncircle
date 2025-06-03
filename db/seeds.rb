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
  User.find_or_create_by!(email_address: "dev@example.com") do |user|
    user.password = "password"
    user.password_confirmation = "password"
    user.role = "admin"
  end

  User.find_or_create_by!(email_address: "user@example.com") do |user|
    user.password = "password"
    user.password_confirmation = "password"
    user.role = "standard"
  end

  claude_agent = Agent.find_or_create_by!(name: "Claude") do |agent|
    agent.docker_image = "claude_max:latest"
    agent.workplace_path = "/workspace"
    agent.home_path = "/home/claude"
    agent.start_arguments = [ "--dangerously-skip-permissions", "--model", "sonnet", "-p", "{PROMPT}" ]
    agent.continue_arguments = [ "-c", "--dangerously-skip-permissions", "--model", "sonnet", "-p", "{PROMPT}" ]
  end

  Volume.find_or_create_by!(agent: claude_agent, name: "home") do |volume|
    volume.path = "/home/claude"
  end

  claude_stream_agent = Agent.find_or_create_by!(name: "Claude Json") do |agent|
    agent.docker_image = "claude_max:latest"
    agent.workplace_path = "/workspace"
    agent.start_arguments = [ "--dangerously-skip-permissions", "--model", "sonnet", "--output-format", "streaming-json", "--verbose", "-p", "{PROMPT}" ]
    agent.continue_arguments = [ "-c", "--dangerously-skip-permissions", "--model", "sonnet", "--output-format", "streaming-json", "--verbose", "-p", "{PROMPT}" ]
    agent.log_processor = "ClaudeStreamingJson"
  end

  Volume.find_or_create_by!(agent: claude_stream_agent, name: "home") do |volume|
    volume.path = "/home/claude"
  end

  Project.find_or_create_by!(name: "SummonCircle") do |project|
    project.repository_url = "https://github.com/JoeDupuis/summoncircle"
  end
end
