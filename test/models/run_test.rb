require "test_helper"

class RunTest < ActiveSupport::TestCase
  # Docker prefixes logs with 8 bytes of metadata
  DOCKER_LOG_HEADER = "\x01\x00\x00\x00\x00\x00\x00"

  test "should identify first run correctly" do
    # Create a new task with no runs
    task = Task.create!(
      project: projects(:one),
      agent: agents(:one),
      user: users(:one),
      status: "active",
      started_at: Time.current
    )

    first_run = task.runs.create!(prompt: "first")
    assert first_run.first_run?

    second_run = task.runs.create!(prompt: "second")
    assert_not second_run.first_run?
  end

  test "execute! handles errors gracefully" do
    run = runs(:one)
    run.update!(status: :pending, started_at: nil, completed_at: nil)
    run.steps.destroy_all

    # Mock Docker::Container to raise an error
    Docker::Container.expects(:create).raises(Docker::Error::NotFoundError, "Image not found")

    # This should not raise an error, but should set status to failed
    assert_nothing_raised do
      run.execute!
    end

    assert run.failed?
    assert_not_nil run.started_at
    assert_not_nil run.completed_at
    assert_equal 1, run.steps.count
    assert_includes run.steps.first.raw_response, "Error:"
    assert_includes run.steps.first.raw_response, "Image not found"
  end

  test "execute! calls Docker container methods correctly for first run" do
    # Create a fresh agent with no volumes
    agent = Agent.create!(
      name: "Test Agent",
      docker_image: "example/image:latest",
      workplace_path: "/workspace",
      start_arguments: [ "echo", "STARTING: {PROMPT}" ],
      continue_arguments: [ "{PROMPT}" ]
    )
    # Create a fresh task with no runs
    task = Task.create!(
      project: projects(:one),
      agent: agent,
      user: users(:one),
      status: "active",
      started_at: Time.current
    )
    run = task.runs.create!(prompt: "test command", status: :pending)

    # Mock git container creation (first run clones the repo)
    git_container = mock("git_container")
    git_container.expects(:start)
    git_container.expects(:wait).returns({ "StatusCode" => 0 })
    git_container.expects(:logs).with(stdout: true, stderr: true).returns(DOCKER_LOG_HEADER + "Cloning...")
    git_container.expects(:delete).with(force: true)

    Docker::Container.expects(:create).with do |params|
      params["Image"] == "alpine/git"
    end.returns(git_container)

    # Expect chown container after git clone
    expect_chown_container

    # For first run, it uses start_arguments
    Docker::Container.expects(:create).with do |params|
      params["Image"] == "example/image:latest" &&
      params["Cmd"] == [ "echo", "STARTING: test command" ] &&
      params["Env"] == [] &&
      params["WorkingDir"] == "/workspace" &&
      params["HostConfig"]["Binds"].size == 1 &&
      params["HostConfig"]["Binds"].any? { |bind| bind.match?(/summoncircle_workplace_volume_.*:\/workspace/) }
    end.returns(mock_container_with_output("\x0bhello world"))

    # Expect git diff container to be created after run completes
    expect_git_diff_container

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count
    assert_equal "hello world", run.steps.first.raw_response
    assert run.steps.last.content.start_with?("Repository state captured")
  end

  test "execute! uses continue_arguments for subsequent runs" do
    # Use existing task with runs
    task = tasks(:one)
    run = runs(:one)
    run.update!(status: :pending, started_at: nil, completed_at: nil)
    run.steps.destroy_all

    # For non-first run, it uses continue_arguments
    Docker::Container.expects(:create).with do |params|
      params["Image"] == "example/image:latest" &&
      params["Cmd"] == [ "echo hello" ] &&
      params["Env"] == [] &&
      params["WorkingDir"] == "/workspace" &&
      params["HostConfig"]["Binds"].size == 2 &&
      params["HostConfig"]["Binds"].include?("summoncircle_MyString_volume_12345678-1234-5678-9abc-123456789abc:MyString") &&
      params["HostConfig"]["Binds"].include?("summoncircle_workplace_volume_abcdef12-3456-7890-abcd-ef1234567890:/workspace")
    end.returns(mock_container_with_output("\x10continued output"))

    # Expect git diff container to be created after run completes
    expect_git_diff_container

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count
    assert_equal "continued output", run.steps.first.raw_response
  end

  test "execute! configures Docker host when specified" do
    original_url = Docker.url

    agent = Agent.create!(
      name: "Test Agent with Docker Host",
      docker_image: "example/image:latest",
      workplace_path: "/workspace",
      docker_host: "tcp://192.168.1.100:2375",
      start_arguments: [ "echo", "{PROMPT}" ]
    )
    task = Task.create!(
      project: projects(:one),
      agent: agent,
      user: users(:one),
      status: "active",
      started_at: Time.current
    )
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock Docker.url= to verify it's called with the correct host and then reset
    Docker.expects(:url=).with("tcp://192.168.1.100:2375").once
    Docker.expects(:url=).with(original_url).once

    # Mock git container creation
    git_container = mock("git_container")
    git_container.expects(:start)
    git_container.expects(:wait).returns({ "StatusCode" => 0 })
    git_container.expects(:logs).with(stdout: true, stderr: true).returns(DOCKER_LOG_HEADER + "Cloning...")
    git_container.expects(:delete).with(force: true)

    Docker::Container.expects(:create).with do |params|
      params["Image"] == "alpine/git"
    end.returns(git_container)

    # Expect chown container after git clone
    expect_chown_container

    # Mock main container creation and execution
    Docker::Container.expects(:create).with do |params|
      params["Image"] == "example/image:latest"
    end.returns(mock_container_with_output("\x04test"))

    # Expect git diff container to be created after run completes
    expect_git_diff_container

    run.execute!

    assert run.completed?
  end

  test "execute! skips Docker host configuration when not specified" do
    agent = Agent.create!(
      name: "Test Agent without Docker Host",
      docker_image: "example/image:latest",
      workplace_path: "/workspace",
      start_arguments: [ "echo", "{PROMPT}" ]
    )
    task = Task.create!(
      project: projects(:one),
      agent: agent,
      user: users(:one),
      status: "active",
      started_at: Time.current
    )
    run = task.runs.create!(prompt: "test", status: :pending)

    # Docker.url= should be called once to reset in main execute ensure block
    Docker.expects(:url=).once

    # Mock git container creation
    git_container = mock("git_container")
    git_container.expects(:start)
    git_container.expects(:wait).returns({ "StatusCode" => 0 })
    git_container.expects(:logs).with(stdout: true, stderr: true).returns(DOCKER_LOG_HEADER + "Cloning...")
    git_container.expects(:delete).with(force: true)

    Docker::Container.expects(:create).with do |params|
      params["Image"] == "alpine/git"
    end.returns(git_container)

    # Expect chown container after git clone
    expect_chown_container

    # Mock main container creation and execution
    Docker::Container.expects(:create).with do |params|
      params["Image"] == "example/image:latest"
    end.returns(mock_container_with_output("\x04test"))

    # Expect git diff container to be created after run completes
    expect_git_diff_container

    run.execute!

    assert run.completed?
  end

  test "execute! resets Docker host after run completes" do
    original_url = "unix:///var/run/docker.sock"
    Docker.url = original_url

    agent = Agent.create!(
      name: "Test Agent with Docker Host",
      docker_image: "example/image:latest",
      workplace_path: "/workspace",
      docker_host: "tcp://192.168.1.100:2375",
      start_arguments: [ "echo", "{PROMPT}" ]
    )
    task = Task.create!(
      project: projects(:one),
      agent: agent,
      user: users(:one),
      status: "active",
      started_at: Time.current
    )
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git container creation
    git_container = mock("git_container")
    git_container.expects(:start)
    git_container.expects(:wait).returns({ "StatusCode" => 0 })
    git_container.expects(:logs).with(stdout: true, stderr: true).returns(DOCKER_LOG_HEADER + "Cloning...")
    git_container.expects(:delete).with(force: true)

    Docker::Container.expects(:create).with do |params|
      params["Image"] == "alpine/git"
    end.returns(git_container)

    # Expect chown container after git clone
    expect_chown_container

    # Mock main container creation and execution
    Docker::Container.expects(:create).with do |params|
      params["Image"] == "example/image:latest"
    end.returns(mock_container_with_output("\x04test"))

    # Expect git diff container to be created after run completes
    expect_git_diff_container

    run.execute!

    assert run.completed?
    assert_equal original_url, Docker.url
    assert_equal 2, run.steps.count
  end

  test "execute! resets Docker host even when run fails" do
    original_url = "unix:///var/run/docker.sock"
    Docker.url = original_url

    agent = Agent.create!(
      name: "Test Agent with Docker Host",
      docker_image: "example/image:latest",
      workplace_path: "/workspace",
      docker_host: "tcp://192.168.1.100:2375",
      start_arguments: [ "echo", "{PROMPT}" ]
    )
    task = Task.create!(
      project: projects(:one),
      agent: agent,
      user: users(:one),
      status: "active",
      started_at: Time.current
    )
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock Docker to fail
    Docker::Container.expects(:create).raises(Docker::Error::NotFoundError, "Image not found")

    run.execute!

    assert run.failed?
    assert_equal original_url, Docker.url
  end

  test "create_steps_from_logs uses agent's log processor" do
    # Create agent with Text processor
    agent = Agent.create!(
      name: "Text Agent",
      docker_image: "example/image:latest",
      workplace_path: "/workspace",
      log_processor: "Text",
      start_arguments: [ "echo", "test" ]
    )
    task = Task.create!(
      project: projects(:one),
      agent: agent,
      user: users(:one),
      status: "active"
    )
    run = task.runs.create!(prompt: "test")

    logs = "Simple log output"
    run.send(:create_steps_from_logs, logs)

    assert_equal 1, run.steps.count
    assert_equal logs, run.steps.first.raw_response
  end

  test "create_steps_from_logs with ClaudeJson processor" do
    # Create agent with ClaudeJson processor
    agent = Agent.create!(
      name: "JSON Agent",
      docker_image: "example/image:latest",
      workplace_path: "/workspace",
      log_processor: "ClaudeJson",
      start_arguments: [ "echo", "test" ]
    )
    task = Task.create!(
      project: projects(:one),
      agent: agent,
      user: users(:one),
      status: "active"
    )
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
    # Create agent with environment variables
    agent = Agent.create!(
      name: "Test Agent with Env Vars",
      docker_image: "example/image:latest",
      workplace_path: "/workspace",
      start_arguments: [ "echo", "{PROMPT}" ],
      env_variables: { "NODE_ENV" => "development", "DEBUG" => "true" }
    )
    task = Task.create!(
      project: projects(:one),
      agent: agent,
      user: users(:one),
      status: "active",
      started_at: Time.current
    )
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git container creation
    git_container = mock("git_container")
    git_container.expects(:start)
    git_container.expects(:wait).returns({ "StatusCode" => 0 })
    git_container.expects(:logs).with(stdout: true, stderr: true).returns(DOCKER_LOG_HEADER + "Cloning...")
    git_container.expects(:delete).with(force: true)

    Docker::Container.expects(:create).with do |params|
      params["Image"] == "alpine/git"
    end.returns(git_container)

    # Expect chown container after git clone
    expect_chown_container

    # Verify that environment variables are passed to Docker container
    Docker::Container.expects(:create).with do |params|
      params["Image"] == "example/image:latest" &&
      params["Cmd"] == [ "echo", "test" ] &&
      params["Env"] == [ "NODE_ENV=development", "DEBUG=true" ] &&
      params["WorkingDir"] == "/workspace" &&
      params["HostConfig"]["Binds"].size == 1 &&
      params["HostConfig"]["Binds"].any? { |bind| bind.match?(/summoncircle_workplace_volume_.*:\/workspace/) }
    end.returns(mock_container_with_output("\x04test"))

    # Expect git diff container to be created after run completes
    expect_git_diff_container

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count
  end

  test "execute! clones repository on first run with default repo_path" do
    project = Project.create!(
      name: "Test Project",
      repository_url: "https://github.com/test/repo.git"
    )
    agent = Agent.create!(
      name: "Test Agent",
      docker_image: "example/image:latest",
      workplace_path: "/workspace",
      start_arguments: [ "echo", "{PROMPT}" ]
    )
    task = Task.create!(
      project: project,
      agent: agent,
      user: users(:one),
      status: "active",
      started_at: Time.current
    )
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git container creation and execution
    git_container = mock("git_container")
    git_container.expects(:start)
    git_container.expects(:wait).returns({ "StatusCode" => 0 })
    git_container.expects(:logs).with(stdout: true, stderr: true).returns(DOCKER_LOG_HEADER + "Cloning into '.'...")
    git_container.expects(:delete).with(force: true)

    Docker::Container.expects(:create).with do |params|
      params["Image"] == "alpine/git" &&
      params["Cmd"] == [ "clone", "https://github.com/test/repo.git", "." ] &&
      params["WorkingDir"] == "/workspace" &&
      params["HostConfig"]["Binds"].size == 1
    end.returns(git_container)

    # Expect chown container after git clone
    expect_chown_container

    # Mock main container
    Docker::Container.expects(:create).with do |params|
      params["Image"] == "example/image:latest"
    end.returns(mock_container_with_output("\x04test"))

    # Expect git diff container to be created after run completes
    expect_git_diff_container

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count
  end

  test "execute! clones repository on first run with custom repo_path" do
    project = Project.create!(
      name: "Test Project",
      repository_url: "https://github.com/test/repo.git",
      repo_path: "myapp"
    )
    agent = Agent.create!(
      name: "Test Agent",
      docker_image: "example/image:latest",
      workplace_path: "/workspace",
      start_arguments: [ "echo", "{PROMPT}" ]
    )
    task = Task.create!(
      project: project,
      agent: agent,
      user: users(:one),
      status: "active",
      started_at: Time.current
    )
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git container creation and execution
    git_container = mock("git_container")
    git_container.expects(:start)
    git_container.expects(:wait).returns({ "StatusCode" => 0 })
    git_container.expects(:logs).with(stdout: true, stderr: true).returns(DOCKER_LOG_HEADER + "Cloning into '/workspace/myapp'...")
    git_container.expects(:delete).with(force: true)

    Docker::Container.expects(:create).with do |params|
      params["Image"] == "alpine/git" &&
      params["Cmd"] == [ "clone", "https://github.com/test/repo.git", "myapp" ] &&
      params["WorkingDir"] == "/workspace" &&
      params["HostConfig"]["Binds"].size == 1
    end.returns(git_container)

    # Expect chown container after git clone
    expect_chown_container

    # Mock main container
    Docker::Container.expects(:create).with do |params|
      params["Image"] == "example/image:latest"
    end.returns(mock_container_with_output("\x04test"))

    # Expect git diff container to be created after run completes
    expect_git_diff_container

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count
  end

  test "execute! handles git clone failure" do
    project = Project.create!(
      name: "Test Project",
      repository_url: "https://github.com/test/repo.git"
    )
    agent = Agent.create!(
      name: "Test Agent",
      docker_image: "example/image:latest",
      workplace_path: "/workspace",
      start_arguments: [ "echo", "{PROMPT}" ]
    )
    task = Task.create!(
      project: project,
      agent: agent,
      user: users(:one),
      status: "active",
      started_at: Time.current
    )
    run = task.runs.create!(prompt: "test", status: :pending)

    # Mock git container creation and execution with failure
    git_container = mock("git_container")
    git_container.expects(:start)
    git_container.expects(:wait).returns({ "StatusCode" => 1 })
    git_container.expects(:logs).with(stdout: true, stderr: true).returns(DOCKER_LOG_HEADER + "fatal: repository not found")
    git_container.expects(:delete).with(force: true)

    Docker::Container.expects(:create).with do |params|
      params["Image"] == "alpine/git"
    end.returns(git_container)

    # No chmod container expected since git clone fails

    run.execute!

    assert run.failed?
    assert_equal 1, run.steps.count
    assert_includes run.steps.first.raw_response, "Failed to clone repository"
  end

  test "execute! skips git clone on subsequent runs" do
    # Use existing task with runs to ensure it's not the first run
    task = tasks(:one)
    run = runs(:one)
    run.update!(status: :pending, started_at: nil, completed_at: nil)
    run.steps.destroy_all

    # Mock main container
    Docker::Container.expects(:create).with do |params|
      params["Image"] == "example/image:latest" # Only the main container
    end.returns(mock_container_with_output("\x04test"))

    # Expect git diff container to be created after run completes
    expect_git_diff_container

    run.execute!

    assert run.completed?
    assert_equal 2, run.steps.count
  end

  test "should_clone_repository? returns false when repository_url is blank" do
    project = Project.create!(name: "Test Project")
    agent = Agent.create!(
      name: "Test Agent",
      docker_image: "example/image:latest",
      workplace_path: "/workspace",
      start_arguments: [ "echo", "test" ]
    )
    task = Task.create!(project: project, agent: agent, user: users(:one), status: "active")
    run = task.runs.create!(prompt: "test")

    assert_not run.send(:should_clone_repository?)
  end

  test "should_clone_repository? returns true when repository_url is present" do
    project = Project.create!(name: "Test Project", repository_url: "https://github.com/test/repo.git")
    agent = Agent.create!(
      name: "Test Agent",
      docker_image: "example/image:latest",
      workplace_path: "/workspace",
      start_arguments: [ "echo", "test" ]
    )
    task = Task.create!(project: project, agent: agent, user: users(:one), status: "active")
    run = task.runs.create!(prompt: "test")

    assert run.send(:should_clone_repository?)
  end

  test "execute! skips git clone when repository_url is blank" do
    project = Project.create!(
      name: "Test Project"
      # No repository_url - should skip git clone
    )

    agent = Agent.create!(
      name: "Test Agent",
      docker_image: "example/image:latest",
      workplace_path: "/workspace",
      start_arguments: [ "echo", "{PROMPT}" ]
    )
    task = Task.create!(
      project: project,
      agent: agent,
      user: users(:one),
      status: "active",
      started_at: Time.current
    )
    run = task.runs.create!(prompt: "test", status: :pending)

    # Ensure Docker::Container.create is only called once (for main container, not git)
    Docker::Container.expects(:create).once.with do |params|
      params["Image"] == "example/image:latest" # Only the main container
    end.returns(mock_container_with_output("\x04test"))

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

  def expect_git_diff_container
    git_diff_container = mock("git_diff_container")
    git_diff_container.expects(:start)
    git_diff_container.expects(:wait).returns({ "StatusCode" => 0 })
    git_diff_container.expects(:logs).with(stdout: true, stderr: true).returns(DOCKER_LOG_HEADER + "")
    git_diff_container.expects(:delete).with(force: true)

    Docker::Container.expects(:create).with do |params|
      params["Entrypoint"] == [ "sh" ] && params["Cmd"] == [ "-c", "git add -N . && git diff HEAD" ] && params["User"] == "1000"
    end.returns(git_diff_container)
  end

  def expect_chown_container(uid = 1000)
    chown_container = mock("chown_container")
    chown_container.expects(:start)
    chown_container.expects(:wait)
    chown_container.expects(:delete).with(force: true)

    Docker::Container.expects(:create).with do |params|
      params["Image"] == "alpine" && params["Cmd"] == [ "chown", "-R", "#{uid}:#{uid}", "." ]
    end.returns(chown_container)
  end
end
