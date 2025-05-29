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

  claude_agent = Agent.find_or_create_by!(name: "Claude") do |agent|
    agent.docker_image = "claude_max:latest"
    agent.start_arguments = ["--dangerously-skip-permissions", "-p", "{PROMPT}"]
    agent.continue_arguments = ["-c", "--dangerously-skip-permissions", "-p", "{PROMPT}"]
  end

  Volume.find_or_create_by!(agent: claude_agent, name: "workspace") do |volume|
    volume.path = "/workspace"
  end

  Volume.find_or_create_by!(agent: claude_agent, name: "home") do |volume|
    volume.path = "/home/claude"
  end
end
