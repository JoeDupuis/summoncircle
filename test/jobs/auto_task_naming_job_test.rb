require "test_helper"

class AutoTaskNamingJobTest < ActiveJob::TestCase
  setup do
    @task = tasks(:one)
    @user = @task.user
    @agent = agents(:one)
    @user.update!(auto_task_naming_agent: @agent)
  end

  test "updates task description when Docker returns valid name" do
    mock_container = mock("container")
    mock_container.expects(:start)
    mock_container.expects(:attach).yields(:stdout, "Awesome Task Name")
    mock_container.expects(:wait)
    mock_container.expects(:delete).with(force: true)
    
    # Mock container file setup calls
    mock_container.expects(:exec).at_least(0)
    
    Docker::Container.expects(:create).returns(mock_container)
    
    AutoTaskNamingJob.perform_now(@task, "Create an awesome feature")
    
    @task.reload
    assert_equal "Awesome Task Name", @task.description
  end

  test "handles JSON log processor output correctly" do
    @agent.update!(log_processor: "ClaudeJson")
    
    mock_container = mock("container")
    mock_container.expects(:start)
    mock_container.expects(:attach).yields(:stdout, '{"type":"content","content":[{"type":"text","text":"JSON Task Name"}]}')
    mock_container.expects(:wait)
    mock_container.expects(:delete).with(force: true)
    mock_container.expects(:exec).at_least(0)
    
    Docker::Container.expects(:create).returns(mock_container)
    
    AutoTaskNamingJob.perform_now(@task, "Create a feature")
    
    @task.reload
    assert_equal "JSON Task Name", @task.description
  end

  test "does nothing when user has no auto_task_naming_agent" do
    @user.update!(auto_task_naming_agent: nil)
    
    Docker::Container.expects(:create).never
    
    AutoTaskNamingJob.perform_now(@task, "Create a feature")
    
    # Task description should remain unchanged
    assert_equal @task.description, @task.reload.description
  end

  test "raises exception when Docker container fails" do
    mock_container = mock("container")
    mock_container.expects(:start).raises(Docker::Error::ServerError)
    mock_container.expects(:delete).with(force: true)
    
    Docker::Container.expects(:create).returns(mock_container)
    
    assert_raises(Docker::Error::ServerError) do
      AutoTaskNamingJob.perform_now(@task, "Create a feature")
    end
  end

  test "does not update task when generated name is empty" do
    mock_container = mock("container")
    mock_container.expects(:start)
    mock_container.expects(:attach).yields(:stdout, "")
    mock_container.expects(:wait)
    mock_container.expects(:delete).with(force: true)
    mock_container.expects(:exec).at_least(0)
    
    Docker::Container.expects(:create).returns(mock_container)
    
    original_description = @task.description
    AutoTaskNamingJob.perform_now(@task, "Create a feature")
    
    @task.reload
    assert_equal original_description, @task.description
  end

  test "creates container with correct configuration" do
    expected_env = @agent.env_strings + @user.env_strings
    
    mock_container = stub(start: nil, attach: "", wait: nil, delete: nil, exec: nil)
    
    Docker::Container.expects(:create).with(
      has_entries(
        "Image" => @agent.docker_image,
        "Env" => expected_env,
        "User" => @agent.user_id.to_s,
        "WorkingDir" => @agent.workplace_path || "/workspace",
        "AttachStdout" => true,
        "AttachStderr" => true
      )
    ).returns(mock_container)
    
    AutoTaskNamingJob.perform_now(@task, "Create a feature")
  end

  test "handles volumes correctly" do
    volume = volumes(:claude_config)
    @agent.volumes << volume
    
    mock_container = stub(start: nil, attach: "", wait: nil, delete: nil, exec: nil)
    
    Docker::Container.expects(:create).with(
      has_entry("HostConfig", has_entry("Binds", includes("#{volume.external_name}:#{volume.path}")))
    ).returns(mock_container)
    
    AutoTaskNamingJob.perform_now(@task, "Create a feature")
  end

  test "sets up container files when user has configurations" do
    @user.update!(
      git_config: "[user]\nname = Test User",
      instructions: "Test instructions",
      ssh_key: "ssh-rsa AAAAB3..."
    )
    @agent.update!(
      home_path: "/home/user",
      instructions_mount_path: "/instructions.txt",
      ssh_mount_path: "/home/user/.ssh/id_rsa"
    )
    
    mock_container = mock("container")
    mock_container.expects(:start)
    mock_container.expects(:attach).yields(:stdout, "Named Task")
    mock_container.expects(:wait)
    mock_container.expects(:delete).with(force: true)
    
    # Allow any exec calls in any order
    mock_container.expects(:exec).at_least(6)
    
    Docker::Container.expects(:create).returns(mock_container)
    
    AutoTaskNamingJob.perform_now(@task, "Create a feature")
    
    @task.reload
    assert_equal "Named Task", @task.description
  end
end
