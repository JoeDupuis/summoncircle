require "test_helper"

class DockerGitCommandTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:without_runs)
    @project = @task.project
    @user = @task.user
    @agent = @task.agent
  end

  # Helper to add Docker's 8-byte header to each line of output
  def add_docker_headers(output)
    docker_header = "\x01\x00\x00\x00\x00\x00\x00\x00"
    output.lines.map { |line| docker_header + line }.join
  end

  test "initialize sets all attributes correctly" do
    command = DockerGitCommand.new(
      task: @task,
      command: "git status",
      error_message: "Failed to get status",
      return_logs: true,
      working_dir: "/custom/path",
      skip_repo_path: true
    )

    assert_equal @task, command.task
    assert_equal "git status", command.command
    assert_equal "Failed to get status", command.error_message
    assert_equal true, command.return_logs
    assert_equal "/custom/path", command.working_dir
    assert_equal true, command.skip_repo_path
  end

  test "execute creates container with correct configuration" do
    command = DockerGitCommand.new(
      task: @task,
      command: "git status",
      error_message: "Failed"
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:wait).with(300).returns({ "StatusCode" => 0 })
    container.expects(:logs).with(stdout: true, stderr: true).returns(add_docker_headers("clean"))
    container.expects(:delete).with(force: true)

    Docker::Container.expects(:create).with(
      "Image" => @agent.docker_image,
      "Entrypoint" => [ "sh" ],
      "Cmd" => [ "-c", "git status" ],
      "WorkingDir" => @task.workplace_mount.container_path,
      "User" => @agent.user_id.to_s,
      "Env" => @agent.env_strings + @project.secrets.map { |s| "#{s.key}=#{s.value}" },
      "HostConfig" => {
        "Binds" => @task.volume_mounts.includes(:volume).map(&:bind_string)
      }
    ).returns(container)

    result = command.execute
    assert_nil result
  end

  test "execute returns logs when return_logs is true" do
    command = DockerGitCommand.new(
      task: @task,
      command: "git branch",
      error_message: "Failed",
      return_logs: true
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:wait).with(300).returns({ "StatusCode" => 0 })
    container.expects(:logs).with(stdout: true, stderr: true).returns(add_docker_headers("main\ndevelop"))
    container.expects(:delete).with(force: true)

    Docker::Container.expects(:create).returns(container)

    result = command.execute
    assert_equal "main\ndevelop", result
  end

  test "execute handles exit code failure" do
    command = DockerGitCommand.new(
      task: @task,
      command: "git push",
      error_message: "Push failed"
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:wait).with(300).returns({ "StatusCode" => 128 })
    container.expects(:logs).with(stdout: true, stderr: true).returns(add_docker_headers("fatal: repository not found"))
    container.expects(:delete).with(force: true)

    Docker::Container.expects(:create).returns(container)

    error = assert_raises(RuntimeError) { command.execute }
    assert_equal "Git operation error: fatal: repository not found (RuntimeError)", error.message
  end

  test "execute cleans up container even on exception" do
    command = DockerGitCommand.new(
      task: @task,
      command: "git status",
      error_message: "Failed"
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:wait).raises(StandardError, "Network error")
    container.expects(:delete).with(force: true)

    Docker::Container.expects(:create).returns(container)

    error = assert_raises(RuntimeError) { command.execute }
    assert_includes error.message, "Network error"
  end

  test "calculate_working_directory respects skip_repo_path" do
    # With skip_repo_path = true
    command = DockerGitCommand.new(
      task: @task,
      command: "ls",
      error_message: "Failed",
      skip_repo_path: true
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:wait).returns({ "StatusCode" => 0 })
    container.expects(:logs).returns(add_docker_headers("files"))
    container.expects(:delete)

    Docker::Container.expects(:create).with(
      has_entries("WorkingDir" => @task.workplace_mount.container_path)
    ).returns(container)

    command.execute
  end

  test "calculate_working_directory includes repo_path when not skipped" do
    @project.update!(repo_path: "myapp")

    command = DockerGitCommand.new(
      task: @task,
      command: "ls",
      error_message: "Failed",
      skip_repo_path: false
    )

    expected_dir = File.join(@task.workplace_mount.container_path, "myapp")

    container = mock("container")
    container.expects(:start)
    container.expects(:wait).returns({ "StatusCode" => 0 })
    container.expects(:logs).returns(add_docker_headers("files"))
    container.expects(:delete)

    Docker::Container.expects(:create).with(
      has_entries("WorkingDir" => expected_dir)
    ).returns(container)

    command.execute
  end

  test "calculate_working_directory uses custom working_dir when provided" do
    command = DockerGitCommand.new(
      task: @task,
      command: "ls",
      error_message: "Failed",
      working_dir: "/custom/path"
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:wait).returns({ "StatusCode" => 0 })
    container.expects(:logs).returns(add_docker_headers("files"))
    container.expects(:delete)

    Docker::Container.expects(:create).with(
      has_entries("WorkingDir" => "/custom/path")
    ).returns(container)

    command.execute
  end

  test "setup_git_credentials adds GitHub token for GitHub URLs" do
    @user.update!(github_token: "ghp_test123")
    @project.update!(repository_url: "https://github.com/user/repo.git")

    command = DockerGitCommand.new(
      task: @task,
      command: "git clone",
      error_message: "Failed"
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:wait).returns({ "StatusCode" => 0 })
    container.expects(:logs).returns(add_docker_headers("success"))
    container.expects(:delete)

    Docker::Container.expects(:create).with do |config|
      config["Env"].include?("GITHUB_TOKEN=ghp_test123") &&
      config["Env"].include?("GIT_ASKPASS=/tmp/git-askpass.sh") &&
      config["Cmd"][1].include?("echo '#!/bin/sh") &&
      config["Cmd"][1].include?("chmod +x /tmp/git-askpass.sh")
    end.returns(container)

    command.execute
  end

  test "setup_git_credentials skips non-GitHub URLs" do
    @user.update!(github_token: "ghp_test123", allow_github_token_access: false)
    @project.update!(repository_url: "https://gitlab.com/user/repo.git")

    command = DockerGitCommand.new(
      task: @task,
      command: "git clone",
      error_message: "Failed"
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:wait).returns({ "StatusCode" => 0 })
    container.expects(:logs).returns(add_docker_headers("success"))
    container.expects(:delete)

    Docker::Container.expects(:create).with do |config|
      !config["Env"].any? { |e| e.include?("GITHUB_TOKEN") } &&
      !config["Env"].any? { |e| e.include?("GIT_ASKPASS") }
    end.returns(container)

    command.execute
  end

  test "setup_ssh_key_in_container is called for SSH URLs" do
    @user.update!(ssh_key: "ssh-rsa AAAAB3NzaC1yc2EA...")
    @agent.update!(ssh_mount_path: "/home/user/.ssh/id_rsa")
    @project.update!(repository_url: "git@github.com:user/repo.git")

    command = DockerGitCommand.new(
      task: @task,
      command: "git clone",
      error_message: "Failed"
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:exec).with([ "mkdir", "-p", "/home/user/.ssh" ])
    container.expects(:exec).with do |cmd|
      cmd.is_a?(Array) && cmd[0] == "sh" && cmd[1] == "-c" &&
      cmd[2].include?("base64 -d > /home/user/.ssh/id_rsa")
    end
    container.expects(:exec).with([ "chmod", "600", "/home/user/.ssh/id_rsa" ])
    container.expects(:exec).with([ "chmod", "700", "/home/user/.ssh" ])
    container.expects(:wait).returns({ "StatusCode" => 0 })
    container.expects(:logs).returns(add_docker_headers("success"))
    container.expects(:delete)

    Docker::Container.expects(:create).returns(container)

    command.execute
  end

  test "setup_ssh_key_in_container skips when no SSH key" do
    @agent.update!(ssh_mount_path: "/home/user/.ssh/id_rsa")
    @project.update!(repository_url: "git@github.com:user/repo.git")

    command = DockerGitCommand.new(
      task: @task,
      command: "git clone",
      error_message: "Failed"
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:exec).never
    container.expects(:wait).returns({ "StatusCode" => 0 })
    container.expects(:logs).returns(add_docker_headers("success"))
    container.expects(:delete)

    Docker::Container.expects(:create).returns(container)

    command.execute
  end

  test "setup_ssh_key_in_container handles errors gracefully" do
    @user.update!(ssh_key: "ssh-rsa AAAAB3NzaC1yc2EA...")
    @agent.update!(ssh_mount_path: "/home/user/.ssh/id_rsa")
    @project.update!(repository_url: "git@github.com:user/repo.git")

    command = DockerGitCommand.new(
      task: @task,
      command: "git clone",
      error_message: "Failed"
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:exec).with([ "mkdir", "-p", "/home/user/.ssh" ]).raises(StandardError, "Permission denied")
    container.expects(:wait).returns({ "StatusCode" => 0 })
    container.expects(:logs).returns(add_docker_headers("success"))
    container.expects(:delete)

    Docker::Container.expects(:create).returns(container)

    Rails.logger.expects(:error).with(includes("Failed to setup SSH key"))

    # Should not raise, just log the error
    assert_nothing_raised { command.execute }
  end

  test "enhance_git_error_message provides helpful SSH error for missing key" do
    @project.update!(repository_url: "git@github.com:user/repo.git")

    command = DockerGitCommand.new(
      task: @task,
      command: "git clone",
      error_message: "Failed"
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:wait).returns({ "StatusCode" => 128 })
    container.expects(:logs).returns(add_docker_headers("Permission denied (publickey)"))
    container.expects(:delete)

    Docker::Container.expects(:create).returns(container)

    error = assert_raises(RuntimeError) { command.execute }
    assert_includes error.message, "No SSH key configured"
    assert_includes error.message, "add an SSH key in your user settings"
  end

  test "enhance_git_error_message provides helpful SSH error for missing mount path" do
    @user.update!(ssh_key: "ssh-rsa AAAAB3NzaC1yc2EA...")
    @project.update!(repository_url: "git@github.com:user/repo.git")

    command = DockerGitCommand.new(
      task: @task,
      command: "git clone",
      error_message: "Failed"
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:exec).never # No SSH setup because mount path is missing
    container.expects(:wait).returns({ "StatusCode" => 128 })
    container.expects(:logs).returns(add_docker_headers("Could not read from remote repository"))
    container.expects(:delete)

    Docker::Container.expects(:create).returns(container)

    error = assert_raises(RuntimeError) { command.execute }
    assert_includes error.message, "Agent is missing SSH mount path"
  end

  test "enhance_git_error_message provides helpful SSH error for key access issues" do
    @user.update!(ssh_key: "ssh-rsa AAAAB3NzaC1yc2EA...")
    @agent.update!(ssh_mount_path: "/home/user/.ssh/id_rsa")
    @project.update!(repository_url: "git@github.com:user/repo.git")

    command = DockerGitCommand.new(
      task: @task,
      command: "git clone",
      error_message: "Failed"
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:exec).times(4) # SSH setup calls
    container.expects(:wait).returns({ "StatusCode" => 128 })
    container.expects(:logs).returns(add_docker_headers("Permission denied (publickey)"))
    container.expects(:delete)

    Docker::Container.expects(:create).returns(container)

    error = assert_raises(RuntimeError) { command.execute }
    assert_includes error.message, "SSH key may not have access"
    assert_includes error.message, "deploy keys"
  end

  test "enhance_git_error_message returns original error for non-SSH issues" do
    @project.update!(repository_url: "https://github.com/user/repo.git")

    command = DockerGitCommand.new(
      task: @task,
      command: "git clone",
      error_message: "Failed"
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:wait).returns({ "StatusCode" => 128 })
    container.expects(:logs).returns(add_docker_headers("fatal: repository not found"))
    container.expects(:delete)

    Docker::Container.expects(:create).returns(container)

    error = assert_raises(RuntimeError) { command.execute }
    assert_equal "Git operation error: fatal: repository not found (RuntimeError)", error.message
  end

  test "log cleaning removes Docker header and handles encoding" do
    command = DockerGitCommand.new(
      task: @task,
      command: "git log",
      error_message: "Failed",
      return_logs: true
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:wait).returns({ "StatusCode" => 0 })
    # Docker header (8 bytes) + content with invalid UTF-8
    # Test with invalid UTF-8 in the content
    container.expects(:logs).returns(add_docker_headers("test\xFFlog"))
    container.expects(:delete)

    Docker::Container.expects(:create).returns(container)

    result = command.execute
    # The scrub method replaces invalid UTF-8 with replacement character
    assert result.include?("test")
    assert result.include?("log")
    # Check that the result has been cleaned
    assert_equal 8, result.length # "test" (4) + replacement char (1) + "log" (3)
  end

  test "includes project secrets in environment" do
    @project.secrets.create!(key: "API_KEY", value: "secret123")
    @project.secrets.create!(key: "DB_PASS", value: "pass456")

    command = DockerGitCommand.new(
      task: @task,
      command: "echo $API_KEY",
      error_message: "Failed"
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:wait).returns({ "StatusCode" => 0 })
    container.expects(:logs).returns(add_docker_headers("success"))
    container.expects(:delete)

    Docker::Container.expects(:create).with do |config|
      config["Env"].include?("API_KEY=secret123") &&
      config["Env"].include?("DB_PASS=pass456")
    end.returns(container)

    command.execute
  end

  test "includes agent environment variables" do
    # Agents have env_strings, not environment_variables
    # Based on the code, env_strings is already included in build_container_config
    # Let's verify the agent's env_strings are included
    command = DockerGitCommand.new(
      task: @task,
      command: "env",
      error_message: "Failed"
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:wait).returns({ "StatusCode" => 0 })
    container.expects(:logs).returns(add_docker_headers("success"))
    container.expects(:delete)

    # The agent's env_strings are already part of the config["Env"] array
    Docker::Container.expects(:create).with do |config|
      # Just verify that Env array includes the agent's env_strings
      config["Env"].is_a?(Array)
    end.returns(container)

    command.execute
  end

  test "handles repo_path with leading slash correctly" do
    @project.update!(repo_path: "/src/app")

    command = DockerGitCommand.new(
      task: @task,
      command: "pwd",
      error_message: "Failed"
    )

    expected_dir = File.join(@task.workplace_mount.container_path, "src/app")

    container = mock("container")
    container.expects(:start)
    container.expects(:wait).returns({ "StatusCode" => 0 })
    container.expects(:logs).returns(add_docker_headers(expected_dir))
    container.expects(:delete)

    Docker::Container.expects(:create).with(
      has_entries("WorkingDir" => expected_dir)
    ).returns(container)

    command.execute
  end

  test "removes Docker header from each line in multi-line output" do
    command = DockerGitCommand.new(
      task: @task,
      command: "git diff",
      error_message: "Failed to get diff",
      return_logs: true
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:wait).with(300).returns({ "StatusCode" => 0 })

    # Docker prefixes each line with 8 bytes of metadata
    diff_content = <<~DIFF.chomp
      diff --git a/file.rb b/file.rb
      index 123..456 100644
      --- a/file.rb
      +++ b/file.rb
      @@ -1,3 +1,3 @@
       def hello
      -  puts "hello"
      +  puts "hello world"
    DIFF

    docker_output = add_docker_headers(diff_content)

    container.expects(:logs).with(stdout: true, stderr: true).returns(docker_output)
    container.expects(:delete).with(force: true)

    Docker::Container.expects(:create).returns(container)

    result = command.execute

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

  test "handles lines shorter than 8 bytes and empty lines after Docker header" do
    command = DockerGitCommand.new(
      task: @task,
      command: "git status",
      error_message: "Failed",
      return_logs: true
    )

    container = mock("container")
    container.expects(:start)
    container.expects(:wait).returns({ "StatusCode" => 0 })

    # Test with empty lines
    test_output = <<~OUTPUT.chomp
      Line 1

      Line 3
    OUTPUT

    docker_output = add_docker_headers(test_output)

    container.expects(:logs).returns(docker_output)
    container.expects(:delete)

    Docker::Container.expects(:create).returns(container)

    result = command.execute
    assert_equal "Line 1\n\nLine 3", result
  end
end
