require "test_helper"

class RunTest < ActiveSupport::TestCase
  test "should identify first run correctly" do
    # Create a new task with no runs
    task = Task.create!(
      project: projects(:one),
      agent: agents(:one),
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
    run.update!(status: :pending, started_at: nil, completed_at: nil, output: nil)

    # Mock Docker::Container to raise an error
    Docker::Container.expects(:create).raises(Docker::Error::NotFoundError, "Image not found")

    # This should not raise an error, but should set status to failed
    assert_nothing_raised do
      run.execute!
    end

    assert run.failed?
    assert_not_nil run.started_at
    assert_not_nil run.completed_at
    assert_includes run.output, "Error:"
    assert_includes run.output, "Image not found"
  end

  test "execute! calls Docker container methods correctly for first run" do
    # Create a fresh task with no runs
    task = Task.create!(
      project: projects(:one),
      agent: agents(:one),
      status: "active",
      started_at: Time.current
    )
    run = task.runs.create!(prompt: "test command", status: :pending)

    # Create mock container
    mock_container = mock("container")

    # For first run, it uses start_arguments
    Docker::Container.expects(:create).with(
      "Image" => "example/image:latest",
      "Cmd" => [ "echo", "STARTING: test command" ],  # start_arguments with substitution
      "WorkingDir" => "/workspace",
      "HostConfig" => {
        "Binds" => [ "task_#{task.id}_volume:/workspace" ]
      }
    ).returns(mock_container)

    mock_container.expects(:start)
    mock_container.expects(:wait)
    # Docker prefixes logs with 8 bytes of metadata
    mock_container.expects(:logs).with(stdout: true, stderr: true).returns("\x01\x00\x00\x00\x00\x00\x00\x0bhello world")
    mock_container.expects(:delete).with(force: true)

    run.execute!

    assert run.completed?
    assert_equal "hello world", run.output
  end

  test "execute! uses continue_arguments for subsequent runs" do
    # Use existing task with runs
    task = tasks(:one)
    run = runs(:one)
    run.update!(status: :pending, started_at: nil, completed_at: nil, output: nil)

    # Mock container
    mock_container = mock("container")

    # For non-first run, it uses continue_arguments
    Docker::Container.expects(:create).with(
      "Image" => "example/image:latest",
      "Cmd" => [ "echo hello" ],  # continue_arguments: ["{PROMPT}"] with "echo hello"
      "WorkingDir" => "/workspace",
      "HostConfig" => {
        "Binds" => [ "task_#{task.id}_volume:/workspace" ]
      }
    ).returns(mock_container)

    mock_container.expects(:start)
    mock_container.expects(:wait)
    # Docker prefixes logs with 8 bytes of metadata
    mock_container.expects(:logs).with(stdout: true, stderr: true).returns("\x01\x00\x00\x00\x00\x00\x00\x10continued output")
    mock_container.expects(:delete).with(force: true)

    run.execute!

    assert run.completed?
    assert_equal "continued output", run.output
  end
end
