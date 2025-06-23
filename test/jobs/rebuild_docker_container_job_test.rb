require "test_helper"

class RebuildDockerContainerJobTest < ActiveJob::TestCase
  setup do
    @task = tasks(:one)
    @task.update!(container_status: "rebuilding", container_id: "123")
  end

  test "updates task status to failed when rebuild fails" do
    mock_builder = mock()
    mock_builder.expects(:remove_existing_container)
    mock_builder.expects(:remove_old_image).with("summoncircle/task-#{@task.id}-dev")
    mock_builder.expects(:build_and_run).raises(StandardError.new("Rebuild failed"))

    DockerContainerBuilder.expects(:new).with(@task).returns(mock_builder)

    assert_raises(StandardError) do
      RebuildDockerContainerJob.perform_now(@task)
    end

    @task.reload
    assert_equal "failed", @task.container_status
    assert_nil @task.container_id
    assert_nil @task.container_name
    assert_nil @task.docker_image_id
  end

  test "creates failed run with error details when rebuild fails" do
    mock_builder = mock()
    mock_builder.expects(:remove_existing_container)
    mock_builder.expects(:remove_old_image).with("summoncircle/task-#{@task.id}-dev")
    error = StandardError.new("Rebuild failed with specific error")
    mock_builder.expects(:build_and_run).raises(error)

    DockerContainerBuilder.expects(:new).with(@task).returns(mock_builder)

    assert_difference "Run.count", 1 do
      assert_difference "Step.count", 1 do
        assert_raises(StandardError) do
          RebuildDockerContainerJob.perform_now(@task)
        end
      end
    end

    run = @task.runs.last
    assert_equal "Docker container rebuild failed", run.prompt
    assert_equal "failed", run.status
    assert_not_nil run.started_at
    assert_not_nil run.completed_at

    step = run.steps.last
    assert_equal "Step::Error", step.type
    assert_equal "Docker rebuild failed", step.content
    assert_includes step.raw_response, "Failed to rebuild Docker container"
    assert_includes step.raw_response, "Rebuild failed with specific error"
  end

  test "broadcasts turbo stream redirect on failure" do
    mock_builder = mock()
    mock_builder.expects(:remove_existing_container)
    mock_builder.expects(:remove_old_image).with("summoncircle/task-#{@task.id}-dev")
    mock_builder.expects(:build_and_run).raises(StandardError.new("Rebuild failed"))

    DockerContainerBuilder.expects(:new).with(@task).returns(mock_builder)

    # Expect at least one broadcast (run callbacks + redirect)
    Turbo::StreamsChannel.expects(:broadcast_append_to).at_least_once

    assert_raises(StandardError) do
      RebuildDockerContainerJob.perform_now(@task)
    end
  end

  test "successful rebuild does not set failed status" do
    mock_builder = mock()
    mock_builder.expects(:remove_existing_container)
    mock_builder.expects(:remove_old_image).with("summoncircle/task-#{@task.id}-dev")
    mock_builder.expects(:build_and_run).returns(true)

    DockerContainerBuilder.expects(:new).with(@task).returns(mock_builder)

    RebuildDockerContainerJob.perform_now(@task)

    @task.reload
    assert_not_equal "failed", @task.container_status
  end
end
