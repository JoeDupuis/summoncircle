#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Testing git clone fix..."
puts "=" * 50

# Test 1: Clone to root of workspace (default)
puts "\nTest 1: Clone to /workspace (repo_path is empty)"
puts "-" * 30

project1 = Project.create!(
  name: "Test Clone to Root",
  repository_url: "https://github.com/octocat/Hello-World.git",
  repo_path: "" # Should clone into /workspace directly
)

agent = Agent.find_or_create_by!(name: "Test Agent") do |a|
  a.docker_image = "ubuntu:latest"
  a.workplace_path = "/workspace"
  a.start_arguments = ["echo", "Started"]
  a.continue_arguments = ["echo", "Continue"]
  a.log_processor = "Text"
end

task1 = Task.create!(project: project1, agent: agent, status: "active", started_at: Time.current)
run1 = task1.runs.create!(prompt: "Test")

puts "Executing run for project: #{project1.name}"
puts "Should clone to: /workspace (using '.' as target)"

begin
  run1.execute!
  puts "✓ Run completed with status: #{run1.status}"
  run1.steps.each { |s| puts "  Step: #{s.raw_response.truncate(100)}" }
rescue => e
  puts "✗ Error: #{e.message}"
end

# Test 2: Clone to subdirectory
puts "\n\nTest 2: Clone to /workspace/myapp (repo_path = 'myapp')"
puts "-" * 30

project2 = Project.create!(
  name: "Test Clone to Subdirectory", 
  repository_url: "https://github.com/octocat/Hello-World.git",
  repo_path: "myapp"
)

task2 = Task.create!(project: project2, agent: agent, status: "active", started_at: Time.current)
run2 = task2.runs.create!(prompt: "Test")

puts "Executing run for project: #{project2.name}"
puts "Should clone to: /workspace/myapp"

begin
  run2.execute!
  puts "✓ Run completed with status: #{run2.status}"
  run2.steps.each { |s| puts "  Step: #{s.raw_response.truncate(100)}" }
rescue => e
  puts "✗ Error: #{e.message}"
end

# Cleanup
[project1, project2].each(&:destroy)

puts "\n" + "=" * 50
puts "Testing complete!"