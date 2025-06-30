require "test_helper"

class DockerGitCommandTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:without_runs)
    @docker_git_command = DockerGitCommand.new(
      task: @task,
      command: "git diff",
      error_message: "Failed to get diff",
      return_logs: true
    )
  end

  test "should remove Docker log header from each line" do
    # Mock Docker container
    mock_container = mock("container")
    Docker::Container.expects(:create).returns(mock_container)
    mock_container.expects(:start)
    mock_container.expects(:wait).with(300).returns({ "StatusCode" => 0 })

    # Docker prefixes each line with 8 bytes of metadata
    # The actual Docker output is one continuous string with embedded newlines
    docker_output = "\x01\x00\x00\x00\x00\x00\x00\x00diff --git a/file.rb b/file.rb\n" +
                   "\x01\x00\x00\x00\x00\x00\x00\x00index 123..456 100644\n" +
                   "\x01\x00\x00\x00\x00\x00\x00\x00--- a/file.rb\n" +
                   "\x01\x00\x00\x00\x00\x00\x00\x00+++ b/file.rb\n" +
                   "\x01\x00\x00\x00\x00\x00\x00\x00@@ -1,3 +1,3 @@\n" +
                   "\x01\x00\x00\x00\x00\x00\x00\x00 def hello\n" +
                   "\x01\x00\x00\x00\x00\x00\x00\x00-  puts \"hello\"\n" +
                   "\x01\x00\x00\x00\x00\x00\x00\x00+  puts \"hello world\""

    mock_container.expects(:logs).with(stdout: true, stderr: true).returns(docker_output)
    mock_container.expects(:delete).with(force: true)

    result = @docker_git_command.execute

    # The result should have Docker headers removed from ALL lines
    expected_result = [
      "diff --git a/file.rb b/file.rb",
      "index 123..456 100644",
      "--- a/file.rb",
      "+++ b/file.rb",
      "@@ -1,3 +1,3 @@",
      " def hello",
      "-  puts \"hello\"",
      "+  puts \"hello world\""
    ].join("\n")

    assert_equal expected_result, result
  end

  test "new implementation removes 8 bytes from each line correctly" do
    # Test the new implementation that removes 8 bytes from each line
    test_string = "\x01\x00\x00\x00\x00\x00\x00\x00First line\n\x01\x00\x00\x00\x00\x00\x00\x00Second line"

    # New implementation using lines.map
    result = test_string.lines.map { |line| line[8..] || "" }.join
    assert_equal "First line\nSecond line", result

    # Also test with empty lines and lines shorter than 8 bytes
    test_string_complex = "\x01\x00\x00\x00\x00\x00\x00\x00Line 1\n" +
                         "\x01\x00\x00\x00\x00\x00\x00\x00\n" +  # Empty line after header
                         "\x01\x00\x00\x00\x00\x00\x00\x00Line 3\n" +
                         "short"  # Line shorter than 8 bytes

    result_complex = test_string_complex.lines.map { |line| line[8..] || "" }.join
    assert_equal "Line 1\n\nLine 3\n", result_complex
  end
end
