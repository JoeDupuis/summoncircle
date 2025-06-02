require "test_helper"

class RunTest < ActiveSupport::TestCase
  # Docker prefixes logs with 8 bytes of metadata
  DOCKER_LOG_HEADER = "\x01\x00\x00\x00\x00\x00\x00"

  test "should identify first run correctly" do
    task = tasks(:without_runs)

    first_run = task.runs.create!(prompt: "first")
    assert first_run.first_run?

    second_run = task.runs.create!(prompt: "second")
    assert_not second_run.first_run?
  end

  test "project_env_strings returns project secrets as environment variables" do
    run = runs(:one)
    project = run.task.project
    
    project.secrets.create!(key: "API_KEY", value: "secret_123")
    project.secrets.create!(key: "DB_PASSWORD", value: "db_pass_456")
    
    env_strings = run.send(:project_env_strings)
    
    assert_includes env_strings, "API_KEY=secret_123"
    assert_includes env_strings, "DB_PASSWORD=db_pass_456"
    assert_equal 2, env_strings.length
  end

  test "project_env_strings returns empty array when no secrets" do
    run = runs(:one)
    
    env_strings = run.send(:project_env_strings)
    
    assert_equal [], env_strings
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

  test "execute! calls Docker container methods correctly for first run" do
    task = tasks(:without_runs)
    run = task.runs.create!(prompt: "test command", status: :pending)

    expect_git_clone_container
    expect_main_container(
      cmd: [ "echo", "STARTING: test command" ],
      output: "\x0bhello world"
    )
    expect_git_diff_container


    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count
    assert_equal "hello world", run.steps.first.raw_response
    assert run.steps.last.content.start_with?("Repository state captured")
  end

  test "execute! uses continue_arguments for subsequent runs" do
    task = tasks(:task_with_runs)
    run = task.runs.last
    run.update!(status: :pending, started_at: nil, completed_at: nil)
    run.steps.destroy_all

    expect_main_container(
      cmd: [ "echo hello" ],
      output: "\x10continued output"
    )
    expect_git_diff_container

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count
    assert_equal "continued output", run.steps.first.raw_response
  end

  test "execute! configures Docker host when specified and resets after completion" do
    original_url = Docker.url

    task = tasks(:with_docker_host)
    run = task.runs.create!(prompt: "test", status: :pending)

    Docker.expects(:url=).with("tcp://192.168.1.100:2375").once
    Docker.expects(:url=).with(original_url).once

    expect_main_container(cmd: [ "echo", "test" ], output: "\x04test")

    run.execute!

    assert run.completed?
    assert_equal original_url, Docker.url
  end

  test "execute! resets Docker host even when run fails" do
    original_url = "unix:///var/run/docker.sock"
    Docker.url = original_url

    task = tasks(:with_docker_host)
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock Docker to fail
    Docker::Container.expects(:create).raises(Docker::Error::NotFoundError, "Image not found")

    run.execute!

    assert run.failed?
    assert_equal original_url, Docker.url
  end

  test "create_steps_from_logs uses agent's log processor" do
    task = tasks(:with_text_processor)
    run = task.runs.create!(prompt: "test")

    logs = "Simple log output"
    run.send(:create_steps_from_logs, logs)

    assert_equal 1, run.steps.count
    assert_equal logs, run.steps.first.raw_response
  end

  test "create_steps_from_logs with ClaudeJson processor" do
    task = tasks(:with_claude_json_processor)
    run = task.runs.create!(prompt: "test")

    logs = '[{"type": "system", "message": "Starting"}, {"type": "user", "content": "Hello"}]'
    run.send(:create_steps_from_logs, logs)

    assert_equal 2, run.steps.count
    assert_equal '{"type":"system","message":"Starting"}', run.steps.first.raw_response
    assert_equal '{"type":"user","content":"Hello"}', run.steps.second.raw_response
    assert_equal "Step::System", run.steps.first.type
    assert_equal "Step::ToolResult", run.steps.second.type
  end

  test "execute! passes environment variables to Docker container" do
    task = tasks(:with_env_vars)
    run = task.runs.create!(prompt: "test", status: :pending)

    expect_git_clone_container
    expect_main_container(
      cmd: [ "echo", "test" ],
      output: "\x04test",
      env: [ "NODE_ENV=development", "DEBUG=true" ],
      binds: includes(regexp_matches(/summoncircle_workplace_volume_.*:\/workspace/))
    )
    expect_git_diff_container

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count
  end

  test "execute! clones repository on first run with default repo_path" do
    task = tasks(:for_repo_clone)
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git container creation and execution
    expect_git_clone_container(
      log_output: "Cloning into '.'...",
      cmd: [ "-c", "git clone https://github.com/test/repo.git ." ],
      working_dir: "/workspace",
      binds: instance_of(Array)
    )

    expect_main_container(cmd: [ "echo", "STARTING: test" ], output: "\x04test")
    expect_git_diff_container

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count
  end

  test "execute! clones repository on first run with custom repo_path" do
    task = tasks(:for_repo_clone_with_path)
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git container creation and execution
    expect_git_clone_container(
      log_output: "Cloning into '/workspace/myapp'...",
      cmd: [ "-c", "git clone https://github.com/test/repo.git myapp" ],
      working_dir: "/workspace",
      binds: instance_of(Array)
    )

    expect_main_container(cmd: [ "echo", "STARTING: test" ], output: "\x04test")
    expect_git_diff_container

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count
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
    assert_includes run.steps.first.raw_response, "Failed to clone repository"
  end

  test "execute! skips git clone on subsequent runs" do
    task = tasks(:task_with_runs)
    run = task.runs.last
    run.update!(status: :pending, started_at: nil, completed_at: nil)
    run.steps.destroy_all

    # Mock main container
    expect_main_container(cmd: [ "echo hello" ], output: "\x04test")

    # Expect git diff container to be created after run completes
    expect_git_diff_container

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count
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
    assert_equal 1, run.steps.count # No repo state step since no repository_url
  end

  private

  def mock_container_with_output(output)
    mock_container = mock("container")
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

  def expect_git_diff_container
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
  end
end
