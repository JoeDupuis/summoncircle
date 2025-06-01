#!/usr/bin/env ruby
require_relative 'config/environment'

# Find or create test data
project = Project.find_or_create_by!(name: "Debug Test Project") do |p|
  p.repository_url = "https://github.com/rails/rails.git"
  p.repo_path = "" # Should clone to /workspace
end

agent = Agent.find_or_create_by!(name: "Debug Test Agent") do |a|
  a.docker_image = "ubuntu:latest"
  a.workplace_path = "/workspace"
  a.start_arguments = ["echo", "Starting with {PROMPT}"]
  a.continue_arguments = ["echo", "{PROMPT}"]
  a.log_processor = "Text"
end

puts "Project: #{project.name}"
puts "Repository URL: #{project.repository_url}"
puts "Repo Path: #{project.repo_path.inspect} (should clone to /workspace)"
puts "Agent: #{agent.name}"
puts "-" * 50

# Create a new task
task = Task.create!(
  project: project,
  agent: agent,
  status: "active",
  started_at: Time.current
)

puts "Created Task ##{task.id}"
puts "Volume mounts: #{task.volume_mounts.count}"
puts "Workplace mount: #{task.workplace_mount.bind_string}"
puts "-" * 50

# Create and execute a run
run = task.runs.create!(prompt: "Debug test run")
puts "Created Run ##{run.id}"
puts "First run? #{run.first_run?}"
puts "-" * 50

# Execute the run synchronously (not via job)
puts "Executing run..."
begin
  run.execute!
rescue => e
  puts "Error during execution: #{e.message}"
  puts "Backtrace:"
  puts e.backtrace.first(5).join("\n")
end

puts "-" * 50
puts "Run status: #{run.status}"
puts "Steps created: #{run.steps.count}"

run.steps.each_with_index do |step, index|
  puts "\nStep #{index + 1}:"
  puts "  Type: #{step.type}"
  puts "  Raw Response: #{step.raw_response}"
  puts "  Content: #{step.content}" if step.content.present?
end

# Try to manually test the git clone
puts "\n" + "=" * 50
puts "Manual git clone test:"
puts "=" * 50

begin
  # Test if we can create the git container
  git_container = Docker::Container.create(
    "Image" => "alpine/git",
    "Cmd" => ["--version"],
    "WorkingDir" => "/workspace"
  )
  
  git_container.start
  git_container.wait
  
  logs = git_container.logs(stdout: true, stderr: true)
  clean_logs = logs.gsub(/^.{8}/m, "").force_encoding("UTF-8").scrub.strip
  
  puts "Git version check: #{clean_logs}"
  
  info = git_container.info
  puts "Container info available: #{!info.nil?}"
  puts "Exit code: #{info.dig("State", "ExitCode")}" if info
  
  git_container.delete(force: true)
rescue => e
  puts "Error testing git container: #{e.message}"
  puts "This might be the root cause!"
end

# Test the actual clone command
puts "\nTesting actual clone command:"
begin
  test_mount = task.workplace_mount
  puts "Using volume mount: #{test_mount.bind_string}"
  
  git_container = Docker::Container.create(
    "Image" => "alpine/git",
    "Cmd" => ["clone", "--depth", "1", "https://github.com/rails/rails.git", "/workspace"],
    "WorkingDir" => "/workspace",
    "HostConfig" => {
      "Binds" => [test_mount.bind_string]
    }
  )
  
  git_container.start
  git_container.wait
  
  logs = git_container.logs(stdout: true, stderr: true)
  clean_logs = logs.gsub(/^.{8}/m, "").force_encoding("UTF-8").scrub.strip
  
  puts "Clone output: #{clean_logs}"
  
  info = git_container.info
  exit_code = info.dig("State", "ExitCode") if info
  puts "Clone exit code: #{exit_code}"
  
  git_container.delete(force: true)
rescue => e
  puts "Error during clone test: #{e.message}"
  puts "Error class: #{e.class}"
end

# Check if alpine/git image exists
puts "\n" + "=" * 50
puts "Checking Docker images:"
puts "=" * 50
begin
  images = Docker::Image.all
  git_image = images.find { |img| img.info["RepoTags"]&.any? { |tag| tag.include?("alpine/git") } }
  if git_image
    puts "alpine/git image found: #{git_image.info["RepoTags"].join(", ")}"
  else
    puts "alpine/git image NOT FOUND - this might be the issue!"
    puts "Run: docker pull alpine/git"
  end
rescue => e
  puts "Error checking images: #{e.message}"
end

puts "\nDebug complete!"