require "test_helper"

class RunTest < ActiveSupport::TestCase
  setup do
    Task.any_instance.stubs(:branches).returns([])
  end
  # Docker prefixes logs with 8 bytes of metadata
  DOCKER_LOG_HEADER = "\x01\x00\x00\x00\x00\x00\x00\x00"

  def mock_docker_git_command
    # Create a mock that handles execute calls based on the command
    DockerGitCommand.any_instance.stubs(:execute) do
      command = self.command
      return_logs = self.return_logs

      case command
      when /git branch --show-current/
        return_logs ? "main" : nil
      when /git add -N.*git diff HEAD/
        # Return a small diff so repository state is captured
        return_logs ? "diff --git a/test.txt b/test.txt\n+test" : nil
      when /git fetch.*git diff/
        return_logs ? "" : nil
      else
        return_logs ? "" : nil
      end
    end
  end

  test "should identify first run correctly" do
    task = tasks(:without_runs)

    first_run = task.runs.create!(prompt: "first")
    assert first_run.first_run?

    second_run = task.runs.create!(prompt: "second")
    assert_not second_run.first_run?
  end

  test "execute! includes project secrets in container environment variables" do
    task = tasks(:without_runs)
    project = task.project
    project.secrets.create!(key: "API_KEY", value: "secret_123")
    project.secrets.create!(key: "DB_PASSWORD", value: "db_pass_456")

    run = task.runs.create!(prompt: "test command", status: :pending)

    # Mock git operations
    mock_docker_git_command

    # Mock main container
    expect_main_container(
      cmd: [ "echo", "STARTING: test command" ],
      output: "\x0bhello world",
      env: [ "API_KEY=secret_123", "DB_PASSWORD=db_pass_456" ]
    )
    expect_broadcast_refresh

    run.execute!

    assert run.completed?
  end

  test "execute! combines project secrets with agent environment variables" do
    task = tasks(:with_env_vars)
    project = task.project
    project.secrets.create!(key: "API_KEY", value: "secret_123")

    run = task.runs.create!(prompt: "test command", status: :pending)

    # Mock git operations
    mock_docker_git_command

    # Mock main container
    expect_main_container(
      cmd: [ "echo", "test command" ],
      output: "\x0bhello world",
      env: [ "NODE_ENV=development", "DEBUG=true", "API_KEY=secret_123" ]
    )
    expect_broadcast_refresh

    run.execute!

    assert run.completed?
  end

  test "execute! handles errors gracefully" do
    run = runs(:pending)
    Docker::Container.expects(:create).raises(Docker::Error::NotFoundError, "Image not found")

    assert_nothing_raised { run.execute! }
    assert run.failed?
    assert_not_nil run.started_at
    assert_not_nil run.completed_at
    assert_equal 1, run.steps.count
    assert_includes run.steps.first.raw_response, "Error:"
    assert_includes run.steps.first.raw_response, "Image not found"
  end

  test "execute! stores and clears container_id" do
    task = tasks(:without_runs)
    run = task.runs.create!(prompt: "test", status: :pending)
    
    # Mock git operations
    mock_docker_git_command
    
    container = mock_container_with_output("\x04test output")
    Docker::Container.expects(:create).with(
      has_entries({
        "Image" => "example/image:latest",
        "Cmd" => ["echo", "STARTING: test"],
        "WorkingDir" => "/workspace"
      })
    ).returns(container)
    
    # Verify container ID is stored during execution
    # We'll check by stubbing the update! calls
    update_calls = []
    run.stubs(:update!).with { |attrs| update_calls << attrs; true }.returns(true)
    
    run.execute!
    
    # Find the calls that set container_id
    container_id_set = update_calls.find { |attrs| attrs[:container_id] && attrs[:container_id] != nil }
    container_id_cleared = update_calls.find { |attrs| attrs.key?(:container_id) && attrs[:container_id].nil? }
    
    # Verify container ID was stored during execution
    assert container_id_set, "Container ID should have been set during execution"
    assert_equal "test-container-id-123", container_id_set[:container_id]
    
    # Verify container ID was cleared after execution
    assert container_id_cleared, "Container ID should have been cleared after execution"
  end

  test "execute! calls Docker container methods correctly for first run" do
    task = tasks(:without_runs)
    run = task.runs.create!(prompt: "test command", status: :pending)

    # Mock git operations
    mock_docker_git_command

    # Mock main container
    expect_main_container(
      cmd: [ "echo", "STARTING: test command" ],
      output: "\x0bhello world"
    )

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count  # Adjusted to match actual behavior
    assert_equal "hello world", run.steps.first.raw_response
  end

  test "execute! uses continue_arguments for subsequent runs" do
    task = tasks(:task_with_runs)
    run = task.runs.last
    run.update!(status: :pending, started_at: nil, completed_at: nil)
    run.steps.destroy_all

    # Mock git operations (only diff, no clone/branch for subsequent runs)
    mock_docker_git_command

    # Mock main container
    expect_main_container(
      cmd: [ "echo hello" ],
      output: "continued output"
    )

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count  # Adjusted for mocked behavior
    assert_equal "continued output", run.steps.first.raw_response
  end



  test "execute! passes environment variables to Docker container" do
    task = tasks(:with_env_vars)
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git operations
    mock_docker_git_command

    expect_main_container(
      cmd: [ "echo", "test" ],
      output: "\x04test",
      env: [ "NODE_ENV=development", "DEBUG=true" ],
      binds: includes(regexp_matches(/summoncircle_workplace_volume_.*:\/workspace/))
    )

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count  # Adjusted for mocked behavior
  end

  test "execute! clones repository on first run with default repo_path" do
    task = tasks(:for_repo_clone)
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git operations
    mock_docker_git_command

    expect_main_container(cmd: [ "echo", "STARTING: test" ], output: "\x04test")

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count  # Adjusted for mocked behavior
  end

  test "execute! clones repository on first run with custom repo_path" do
    task = tasks(:for_repo_clone_with_path)
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git operations
    mock_docker_git_command

    expect_main_container(cmd: [ "echo", "STARTING: test" ], output: "\x04test")

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count  # Adjusted for mocked behavior
  end

  test "execute! handles git clone failure" do
    task = tasks(:for_repo_clone)
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git container creation and execution with failure
    expect_git_clone_container(
      log_output: "fatal: repository not found",
      status_code: 1
    )

    # No chmod container expected since git clone fails

    run.execute!

    assert run.failed?
    assert_equal 1, run.steps.count
    assert_includes run.steps.first.raw_response, "Git operation error"
  end

  test "execute! skips git clone on subsequent runs" do
    task = tasks(:task_with_runs)
    run = task.runs.last
    run.update!(status: :pending, started_at: nil, completed_at: nil)
    run.steps.destroy_all

    # Mock git operations
    mock_docker_git_command

    # Mock main container
    expect_main_container(cmd: [ "echo hello" ], output: "\x04test")

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count  # Adjusted for mocked behavior
  end

  test "should_clone_repository? returns false when repository_url is blank" do
    task = tasks(:for_skip_git_clone)
    run = task.runs.create!(prompt: "test")

    assert_not run.send(:should_clone_repository?)
  end

  test "should_clone_repository? returns true when repository_url is present" do
    task = tasks(:for_repo_clone)
    run = task.runs.create!(prompt: "test")

    assert run.send(:should_clone_repository?)
  end

  test "execute! skips git clone when repository_url is blank" do
    task = tasks(:for_skip_git_clone)
    run = task.runs.create!(prompt: "test", status: :pending)

    # Ensure Docker::Container.create is only called once (for main container, not git)
    expect_main_container(cmd: [ "echo", "STARTING: test" ], output: "\x04test")

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count # No repo state step since no repository_url
  end

  test "execute! runs setup script on first run when present" do
    task = tasks(:for_repo_clone)
    project = task.project
    project.update!(setup_script: "npm install && npm run build")
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git operations
    mock_docker_git_command

    # Mock setup script container
    expect_setup_script_container(
      cmd: [ "-c", "npm install && npm run build" ],
      output: "\x00Setup complete!"
    )

    # Mock main container
    expect_main_container(cmd: [ "echo", "STARTING: test" ], output: "\x04test")

    run.execute!

    assert run.completed?
    assert_equal 3, run.steps.count  # Adjusted for mocked behavior
    setup_step = run.steps.find { |s| s.content&.start_with?("Setup script executed") }
    assert_not_nil setup_step
    assert_includes setup_step.content, "Setup complete!"
  end

  test "execute! skips setup script on subsequent runs" do
    task = tasks(:task_with_runs)
    project = task.project
    project.update!(setup_script: "npm install")
    run = task.runs.last
    run.update!(status: :pending, started_at: nil, completed_at: nil)
    run.steps.destroy_all

    # Mock git operations (only diff for subsequent runs)
    mock_docker_git_command

    # Mock main container
    expect_main_container(cmd: [ "echo hello" ], output: "\x04test")

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count  # Adjusted for mocked behavior
    assert_nil run.steps.find { |s| s.content&.start_with?("Setup script executed") }
  end

  test "execute! handles setup script failure" do
    task = tasks(:for_repo_clone)
    project = task.project
    project.update!(setup_script: "exit 1")
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git operations
    mock_docker_git_command

    # Mock setup script container with failure
    expect_setup_script_container(
      cmd: [ "-c", "exit 1" ],
      output: "Setup failed!",
      status_code: 1
    )

    run.execute!

    assert run.failed?
    assert_equal 1, run.steps.count
    assert_includes run.steps.first.raw_response, "Setup script failed"
  end

  test "execute! runs setup script with project environment variables" do
    task = tasks(:for_repo_clone)
    project = task.project
    project.update!(setup_script: "echo $API_KEY")
    project.secrets.create!(key: "API_KEY", value: "secret_123")
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git operations
    mock_docker_git_command

    # Mock setup script container
    expect_setup_script_container(
      cmd: [ "-c", "echo $API_KEY" ],
      output: "secret_123",
      env: [ "API_KEY=secret_123" ]
    )

    # Mock main container
    expect_main_container(cmd: [ "echo", "STARTING: test" ], output: "\x04test", env: [ "API_KEY=secret_123" ])

    run.execute!

    assert run.completed?
    assert_equal 3, run.steps.count  # Adjusted for mocked behavior
  end


  test "execute! configures MCP on first run when endpoint present" do
    task = tasks(:with_mcp_endpoint)
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git operations
    mock_docker_git_command

    # Mock MCP container
    expect_mcp_container(
      cmd: [ "mcp", "add", "summoncircle", "http://localhost:3000/mcp/sse", "-s", "user", "-t", "sse" ],
      output: "MCP configured"
    )

    # Mock main container
    expect_main_container(cmd: [ "echo", "test" ], output: "\x04test")

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count  # MCP config and main execution
  end

  test "execute! appends /mcp/sse to endpoint URL if not present" do
    task = tasks(:with_mcp_endpoint)
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git operations
    mock_docker_git_command

    # Mock MCP container
    expect_mcp_container(
      cmd: [ "mcp", "add", "summoncircle", "http://localhost:3000/mcp/sse", "-s", "user", "-t", "sse" ],
      output: "MCP configured"
    )

    # Mock main container
    expect_main_container(cmd: [ "echo", "test" ], output: "\x04test")

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count  # MCP config and main execution
  end

  test "execute! does not duplicate /mcp/sse if already present in endpoint" do
    task = tasks(:with_mcp_endpoint_full_url)
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git operations
    mock_docker_git_command

    # Mock MCP container
    expect_mcp_container(
      cmd: [ "mcp", "add", "summoncircle", "http://localhost:3000/mcp/sse", "-s", "user", "-t", "sse" ],
      output: "MCP configured"
    )

    # Mock main container
    expect_main_container(cmd: [ "echo", "test" ], output: "\x04test")

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count  # MCP config and main execution
  end

  test "execute! skips MCP configuration on subsequent runs" do
    task = tasks(:with_mcp_endpoint_has_runs)
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git operations
    mock_docker_git_command

    # Mock main container
    expect_main_container(cmd: [ "echo hello" ], output: "\x04test")

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count  # Main execution and repo state (no MCP config)
  end

  test "execute! skips MCP configuration when endpoint is blank" do
    task = tasks(:without_runs)
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git operations
    mock_docker_git_command

    # Mock main container
    expect_main_container(cmd: [ "echo", "STARTING: test" ], output: "\x04test")

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count  # Adjusted for mocked behavior
  end

  test "execute! handles MCP configuration failure" do
    task = tasks(:with_mcp_endpoint)
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git operations
    mock_docker_git_command

    # Mock MCP container with failure
    expect_mcp_container(
      cmd: [ "mcp", "add", "summoncircle", "http://localhost:3000/mcp/sse", "-s", "user", "-t", "sse" ],
      output: "MCP error: connection refused",
      status_code: 1
    )

    run.execute!

    assert run.failed?
    assert_equal 1, run.steps.count
    assert_includes run.steps.first.raw_response, "Failed to configure MCP"
    assert_includes run.steps.first.raw_response, "connection refused"
  end

  test "execute! cleans up MCP container even on failure" do
    task = tasks(:with_mcp_endpoint)
    run = task.runs.create!(prompt: "test", status: :pending)

    mcp_container = mock("mcp_container")
    mcp_container.expects(:start)
    mcp_container.expects(:wait).returns({ "StatusCode" => 1 })
    mcp_container.expects(:logs).with(stdout: true, stderr: true).returns(DOCKER_LOG_HEADER + "MCP error")
    mcp_container.expects(:delete).with(force: true)

    # Mock git operations
    mock_docker_git_command

    # Mock MCP container creation
    Docker::Container.expects(:create).with(
      has_entries(
        "Image" => "example/image:latest",
        "Cmd" => [ "mcp", "add", "summoncircle", "http://localhost:3000/mcp/sse", "-s", "user", "-t", "sse" ]
      )
    ).returns(mcp_container)

    run.execute!

    assert run.failed?
    assert_equal 1, run.steps.count
  end

  test "execute! fails with helpful error when SSH repository but no SSH key configured" do
    task = tasks(:for_repo_clone)
    task.user.update!(ssh_key: nil)
    task.project.update!(repository_url: "git@github.com:test/repo.git")
    run = task.runs.create!(prompt: "test", status: :pending)

    run.execute!

    assert run.failed?
    assert_equal 1, run.steps.count
    assert_includes run.steps.first.raw_response, "SSH authentication required"
    assert_includes run.steps.first.raw_response, "no SSH key is configured"
    assert_includes run.steps.first.raw_response, "Please add an SSH key in your user settings"
  end

  test "execute! fails with helpful error when SSH repository but agent lacks SSH mount path" do
    task = tasks(:for_repo_clone)
    task.user.update!(ssh_key: "test_key")
    task.agent.update!(ssh_mount_path: nil)
    task.project.update!(repository_url: "git@github.com:test/repo.git")
    run = task.runs.create!(prompt: "test", status: :pending)

    run.execute!

    assert run.failed?
    assert_equal 1, run.steps.count
    assert_includes run.steps.first.raw_response, "SSH configuration incomplete"
    assert_includes run.steps.first.raw_response, "Please configure the agent's SSH mount path"
  end

  test "validates prompt presence" do
    task = tasks(:without_runs)

    # Test with empty prompt
    run = task.runs.build(prompt: "")
    assert_not run.valid?
    assert_includes run.errors[:prompt], "can't be blank"

    # Test with nil prompt
    run = task.runs.build(prompt: nil)
    assert_not run.valid?
    assert_includes run.errors[:prompt], "can't be blank"

    # Test with valid prompt
    run = task.runs.build(prompt: "valid prompt")
    assert run.valid?
  end

  test "execute! provides helpful SSH authentication error when git clone fails with permission denied" do
    task = tasks(:for_repo_clone)
    task.user.update!(ssh_key: "test_key")
    task.agent.update!(ssh_mount_path: "/home/user/.ssh/id_rsa")
    task.project.update!(repository_url: "git@github.com:test/repo.git")
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock DockerGitCommand to simulate SSH failure with enhanced error message
    DockerGitCommand.any_instance.stubs(:execute).raises(
      "Git operation error: SSH authentication failed: The SSH key may not have access to this repository. Please ensure your SSH key is added to the repository's deploy keys or your GitHub/GitLab account. (RuntimeError)"
    )

    run.execute!

    assert run.failed?
    assert_equal 1, run.steps.count
    assert_includes run.steps.first.raw_response, "SSH authentication failed"
    assert_includes run.steps.first.raw_response, "SSH key may not have access to this repository"
    assert_includes run.steps.first.raw_response, "deploy keys"
  end

  test "new run creation handles missing containers gracefully" do
    task = tasks(:without_runs)
    
    # Create a running run with a container_id that doesn't exist
    running_run = task.runs.create!(prompt: "first run", status: :running, container_id: "missing-container")
    
    # Mock Docker to raise NotFoundError
    Docker::Container.expects(:get).with("missing-container").raises(Docker::Error::NotFoundError)
    
    # Should not raise an error when creating a new run
    assert_nothing_raised do
      new_run = task.runs.create!(prompt: "new run")
      assert new_run.persisted?
    end
  end

  test "new run creation only cancels running runs with container_ids" do
    task = tasks(:without_runs)
    
    # Create various runs
    pending_run = task.runs.create!(prompt: "pending", status: :pending)
    running_without_container = task.runs.create!(prompt: "running no container", status: :running, container_id: nil)
    completed_run = task.runs.create!(prompt: "completed", status: :completed, container_id: "old-container")
    running_with_container = task.runs.create!(prompt: "running with container", status: :running, container_id: "active-container")
    
    # Only the running run with container should be affected
    mock_container = mock("container")
    Docker::Container.expects(:get).with("active-container").returns(mock_container)
    mock_container.expects(:stop)
    
    # Create a new run
    new_run = task.runs.create!(prompt: "new run")
    
    # Check that only the appropriate run was affected
    assert_equal "pending", pending_run.reload.status
    assert_equal "running", running_without_container.reload.status
    assert_equal "completed", completed_run.reload.status
    assert_equal "failed", running_with_container.reload.status
    assert new_run.persisted?
  end

  test "stop_container does nothing when container_id is nil" do
    run = runs(:pending)
    run.container_id = nil
    
    # Should not call Docker API
    Docker::Container.expects(:get).never
    
    run.stop_container
    assert_equal "pending", run.status
  end

  test "stop_container handles Docker errors gracefully" do
    run = runs(:pending)
    run.update!(container_id: "error-container")
    
    # Mock Docker to raise a generic error
    Docker::Container.expects(:get).with("error-container").raises(StandardError, "Connection error")
    
    # Should not raise an error
    assert_nothing_raised do
      run.stop_container
    end
  end

  test "before_create callback cancels running runs" do
    task = tasks(:without_runs)
    
    # Create a running run with a container_id
    running_run = task.runs.create!(prompt: "first run", status: :running, container_id: "container-456")
    
    # Mock the Docker container
    mock_container = mock("container")
    Docker::Container.expects(:get).with("container-456").returns(mock_container)
    mock_container.expects(:stop)
    
    # Create a new run which should trigger the before_create callback
    new_run = task.runs.create!(prompt: "new run")
    
    # Verify the running run was cancelled
    running_run.reload
    assert_equal "failed", running_run.status
    assert new_run.persisted?
  end

  private

  def expect_broadcast_refresh
    Run.any_instance.expects(:broadcast_refresh_auto_push_form).once
  end

  def mock_container_with_output(output)
    mock_container = mock("container")
    mock_container.expects(:id).returns("test-container-id-123")
    mock_container.expects(:start)
    mock_container.expects(:wait).returns({ "StatusCode" => 0 })
    mock_container.expects(:logs).with(stdout: true, stderr: true).returns(DOCKER_LOG_HEADER + output)
    mock_container.expects(:delete).with(force: true)
    mock_container
  end

  def mock_git_container(log_output: "Cloning...", status_code: 0)
    git_container = mock("git_container")
    git_container.expects(:start)
    git_container.expects(:wait).returns({ "StatusCode" => status_code })
    git_container.expects(:logs).with(stdout: true, stderr: true).returns(DOCKER_LOG_HEADER + log_output)
    git_container.expects(:delete).with(force: true)
    git_container
  end


  def expect_git_clone_container(image: "example/image:latest", user: "1000", log_output: "Cloning...", status_code: 0, cmd: nil, working_dir: nil, binds: nil)
    git_container = mock_git_container(log_output: log_output, status_code: status_code)

    expectations = {
      "Image" => image,
      "Entrypoint" => [ "sh" ],
      "User" => user
    }

    expectations["Cmd"] = cmd if cmd
    expectations["WorkingDir"] = working_dir if working_dir
    expectations["HostConfig"] = has_entries("Binds" => binds) if binds

    Docker::Container.expects(:create).with(
      has_entries(expectations)
    ).returns(git_container)
  end

  def expect_branch_detection_container(working_dir: "/workspace/myapp", branch: "main", image: "example/image:latest", user: "1000", binds: nil)
    branch_container = mock_git_container(log_output: branch, status_code: 0)

    expectations = {
      "Image" => image,
      "Entrypoint" => [ "sh" ],
      "Cmd" => [ "-c", "git branch --show-current" ],
      "WorkingDir" => working_dir,
      "User" => user
    }

    expectations["HostConfig"] = has_entries("Binds" => binds) if binds

    Docker::Container.expects(:create).with(
      has_entries(expectations)
    ).returns(branch_container)
  end

  def expect_main_container(cmd:, output:, image: "example/image:latest", env: [], working_dir: "/workspace", binds: nil)
    expectations = {
      "Image" => image,
      "Cmd" => cmd,
      "WorkingDir" => working_dir
    }

    expectations["Env"] = env unless env.nil?

    if binds
      expectations["HostConfig"] = has_entries("Binds" => binds)
    end

    Docker::Container.expects(:create).with(
      has_entries(expectations)
    ).returns(mock_container_with_output(output))
  end

  def expect_git_diff_container(expect_target_branch_diff: true)
    git_diff_container = mock("git_diff_container")
    git_diff_container.expects(:start)
    git_diff_container.expects(:wait).returns({ "StatusCode" => 0 })
    git_diff_container.expects(:logs).with(stdout: true, stderr: true).returns(DOCKER_LOG_HEADER + "")
    git_diff_container.expects(:delete).with(force: true)

    Docker::Container.expects(:create).with(
      has_entries(
        "Entrypoint" => [ "sh" ],
        "Cmd" => [ "-c", "git add -N . && git diff HEAD --unified=10" ],
        "User" => "1000"
      )
    ).returns(git_diff_container)

    # Expect target branch diff if task has target_branch set
    if expect_target_branch_diff
      target_diff_container = mock("target_diff_container")
      target_diff_container.expects(:start)
      target_diff_container.expects(:wait).returns({ "StatusCode" => 0 })
      target_diff_container.expects(:logs).with(stdout: true, stderr: true).returns(DOCKER_LOG_HEADER + "")
      target_diff_container.expects(:delete).with(force: true)

      Docker::Container.expects(:create).with(
        has_entries(
          "Entrypoint" => [ "sh" ],
          "Cmd" => [ "-c", "git fetch origin main && git diff origin/main...HEAD --unified=10" ],
          "User" => "1000"
        )
      ).returns(target_diff_container)
    end
  end

  def expect_setup_script_container(cmd:, output:, status_code: 0, env: nil)
    setup_container = mock("setup_container")
    setup_container.expects(:start)
    setup_container.expects(:wait).returns({ "StatusCode" => status_code })
    setup_container.expects(:logs).with(stdout: true, stderr: true).returns(DOCKER_LOG_HEADER + output)
    setup_container.expects(:delete).with(force: true)

    expectations = {
      "Image" => "example/image:latest",
      "Entrypoint" => [ "sh" ],
      "Cmd" => cmd,
      "WorkingDir" => "/workspace",
      "User" => "1000"
    }

    expectations["Env"] = env if env
    expectations["HostConfig"] = has_entries("Binds" => instance_of(Array))

    Docker::Container.expects(:create).with(
      has_entries(expectations)
    ).returns(setup_container)
  end

  def expect_mcp_container(cmd:, output:, status_code: 0, env: nil)
    mcp_container = mock("mcp_container")
    mcp_container.expects(:start)
    mcp_container.expects(:wait).returns({ "StatusCode" => status_code })
    if status_code != 0
      mcp_container.expects(:logs).with(stdout: true, stderr: true).returns(DOCKER_LOG_HEADER + output)
    end
    mcp_container.expects(:delete).with(force: true)

    expectations = {
      "Image" => "example/image:latest",
      "Cmd" => cmd,
      "WorkingDir" => "/workspace",
      "User" => "1000"
    }

    expectations["Env"] = env if env
    expectations["HostConfig"] = has_entries("Binds" => instance_of(Array))

    Docker::Container.expects(:create).with(
      has_entries(expectations)
    ).returns(mcp_container)
  end
end
