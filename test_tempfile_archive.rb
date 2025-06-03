#!/usr/bin/env ruby

require 'docker'
require 'tempfile'

puts "Testing Tempfile with archive_in..."

# Create a container
container = Docker::Container.create(
  "Image" => "alpine:latest",
  "Cmd" => ["sleep", "30"]
)
container.start

# Test with Tempfile
temp_file = Tempfile.new([".gitconfig", ""])
puts "Tempfile path: #{temp_file.path}"
puts "Tempfile basename: #{File.basename(temp_file.path)}"
temp_file.write("[user]\n  name = Test")
temp_file.close

container.archive_in(temp_file.path, "/root")

# Check what was created
result = container.exec(["ls", "-la", "/root/"])
puts "\nFiles in /root/:"
puts result[0].join

# Check if .gitconfig exists
result = container.exec(["cat", "/root/.gitconfig"])
puts "\nTrying to read /root/.gitconfig:"
puts result[0].join

# Clean up
temp_file.unlink
container.stop
container.delete(force: true)