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

  test "broadcasts turbo stream update on failure" do
    mock_builder = mock()
    mock_builder.expects(:remove_existing_container)
    mock_builder.expects(:remove_old_image).with("summoncircle/task-#{@task.id}-dev")
    mock_builder.expects(:build_and_run).raises(StandardError.new("Rebuild failed"))

    DockerContainerBuilder.expects(:new).with(@task).returns(mock_builder)

    Turbo::StreamsChannel.expects(:broadcast_replace_to).with(
      @task,
      target: "docker_controls",
      partial: "tasks/docker_controls",
      locals: { task: @task }
    )

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
