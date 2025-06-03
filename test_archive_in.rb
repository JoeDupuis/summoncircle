#!/usr/bin/env ruby

# Test script for Docker archive_in functionality
# Run with: bin/rails runner test_archive_in.rb

require 'docker'
require 'tempfile'
require 'stringio'

puts "Testing Docker archive_in..."

# Create a simple container
container = Docker::Container.create(
  "Image" => "alpine:latest",
  "Cmd" => ["sleep", "300"],
  "WorkingDir" => "/tmp"
)

puts "Container created: #{container.id[0..12]}"

# Start the container
container.start

container.archive_in("qwe.txt", "/root")
debugger
puts "Container started"

# Test 1: Using a temp file
puts "\n=== Test 1: Using temp file ==="
# temp_file = Tempfile.new(['test', '.txt'])
# temp_file.write("Hello from temp file!")
# temp_file.close

# exit 0
# begin
#   container.archive_in(temp_file.path, "/tmp")
#   puts "✓ Temp file archive_in succeeded"
# rescue => e
#   puts "✗ Temp file failed: #{e.message}"
# ensure
#   temp_file.unlink
# end

# # Test 2: Using StringIO directly
# puts "\n=== Test 2: Using StringIO directly ==="
# tar_stream = StringIO.new.tap do |io|
#   Gem::Package::TarWriter.new(io) do |tar|
#     tar.add_file("lol.txt", 0644) do |tf|
#       tf.write("Hello from StringIO!")
#     end
#   end
#   io.rewind
# end

# begin
#   container.archive_in(tar_stream, "/tmp")
#   puts "✓ StringIO archive_in succeeded"
# rescue => e
#   puts "✗ StringIO failed: #{e.message}"
# end

# # Test 3: Using archive_in_stream
# puts "\n=== Test 3: Using archive_in_stream ==="
# tar_stream2 = StringIO.new.tap do |io|
#   Gem::Package::TarWriter.new(io) do |tar|
#     tar.add_file("stream.txt", 0644) do |tf|
#       tf.write("Hello from archive_in_stream!")
#     end
#   end
#   io.rewind
# end

# begin
#   container.archive_in_stream("/tmp") do
#     tar_stream2.read
#   end
#   puts "✓ archive_in_stream succeeded"
# rescue => e
#   puts "✗ archive_in_stream failed: #{e.message}"
# end

# # Check what files were created
# puts "\n=== Checking created files ==="
# output = container.exec(["ls", "-la", "/tmp/"])
# puts output[0].join

# Check content of files
# [""].each do |pattern|
#   begin
#     result = container.exec(["sh", "-c", "cat #{pattern} 2>/dev/null"])
#     if result[0].join.strip.length > 0
#       puts "\nContent of #{pattern}: #{result[0].join.strip}"
#     end
#   rescue
#     # File might not exist
#   end
# end

# Cleanup
container.stop
container.delete(force: true)
puts "\nContainer cleaned up"
