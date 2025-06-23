require "test_helper"

class BuildDockerContainerJobTest < ActiveJob::TestCase
  setup do
    @task = tasks(:one)
    @task.update!(container_status: "building")
  end

  test "updates task status to failed when build fails" do
    mock_builder = mock()
    mock_builder.expects(:build_and_run).raises(StandardError.new("Build failed"))

    DockerContainerBuilder.expects(:new).with(@task).returns(mock_builder)

    assert_raises(StandardError) do
      BuildDockerContainerJob.perform_now(@task)
    end

    @task.reload
    assert_equal "failed", @task.container_status
    assert_nil @task.container_id
    assert_nil @task.container_name
    assert_nil @task.docker_image_id
  end

  test "creates failed run with error details when build fails" do
    mock_builder = mock()
    error = StandardError.new("Build failed with specific error")
    mock_builder.expects(:build_and_run).raises(error)

    DockerContainerBuilder.expects(:new).with(@task).returns(mock_builder)

    assert_difference "Run.count", 1 do
      assert_difference "Step.count", 2 do
        assert_raises(StandardError) do
          BuildDockerContainerJob.perform_now(@task)
        end
      end
    end

    run = @task.runs.last
    assert_equal "Docker container build failed", run.prompt
    assert_equal "failed", run.status
    assert_not_nil run.started_at
    assert_not_nil run.completed_at

    # Check the error step (first one)
    error_step = run.steps.first
    assert_equal "Step::Error", error_step.type
    assert_includes error_step.content, "Failed to build Docker container"
    assert_includes error_step.raw_response, "Build failed with specific error"

    # Check the result step (for chat display)
    result_step = run.steps.last
    assert_equal "Step::Result", result_step.type
    assert_equal "Docker build failed", result_step.content
  end

  test "broadcasts turbo stream updates on failure" do
    mock_builder = mock()
    mock_builder.expects(:build_and_run).raises(StandardError.new("Build failed"))

    DockerContainerBuilder.expects(:new).with(@task).returns(mock_builder)

    # Expect all three broadcasts
    Turbo::StreamsChannel.expects(:broadcast_replace_to).times(3)

    assert_raises(StandardError) do
      BuildDockerContainerJob.perform_now(@task)
    end
  end

  test "successful build does not set failed status" do
    mock_builder = mock()
    mock_builder.expects(:build_and_run).returns(true)

    DockerContainerBuilder.expects(:new).with(@task).returns(mock_builder)

    BuildDockerContainerJob.perform_now(@task)

    @task.reload
    assert_not_equal "failed", @task.container_status
  end
end
