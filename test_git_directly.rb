#!/usr/bin/env ruby
require_relative 'config/environment'
require 'docker'

puts "Testing git clone directly with Docker..."
puts "=" * 50

# Create a test volume
volume_name = "test_git_clone_#{SecureRandom.hex(4)}"

begin
  # Test 1: Clone into current directory
  puts "\nTest 1: Clone into current directory with '.'"
  puts "-" * 30
  
  container = Docker::Container.create(
    "Image" => "alpine/git",
    "Cmd" => ["clone", "https://github.com/octocat/Hello-World.git", "."],
    "WorkingDir" => "/workspace",
    "HostConfig" => {
      "Binds" => ["#{volume_name}:/workspace"]
    }
  )
  
  container.start
  exit_status = container.wait
  
  logs = container.logs(stdout: true, stderr: true)
  clean_logs = logs.gsub(/^.{8}/m, "").force_encoding("UTF-8").scrub.strip
  
  info = container.info
  exit_code = info.dig("State", "ExitCode")
  
  puts "Output: #{clean_logs}"
  puts "Exit code: #{exit_code}"
  puts "Exit status: #{exit_status}"
  
  container.delete(force: true)
  
  # List what's in the volume
  ls_container = Docker::Container.create(
    "Image" => "alpine",
    "Cmd" => ["ls", "-la", "/workspace"],
    "WorkingDir" => "/workspace",
    "HostConfig" => {
      "Binds" => ["#{volume_name}:/workspace"]
    }
  )
  
  ls_container.start
  ls_container.wait
  
  ls_logs = ls_container.logs(stdout: true, stderr: true)
  clean_ls_logs = ls_logs.gsub(/^.{8}/m, "").force_encoding("UTF-8").scrub.strip
  
  puts "\nContents of /workspace after clone:"
  puts clean_ls_logs
  
  ls_container.delete(force: true)
  
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

# Clean up the test volume
begin
  Docker::Volume.get(volume_name).remove
rescue
  # Ignore if volume doesn't exist
end

puts "\n" + "=" * 50
puts "Test complete!"