require "test_helper"

class TaskTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "run method should create a new run and queue job" do
    task = tasks(:two)

    assert_difference "Run.count", 1 do
      assert_enqueued_jobs 1, only: RunJob do
        run = task.run("test command")
        assert_equal "test command", run.prompt
        assert run.pending?
      end
    end
  end

  test "workplace_mount returns nil when agent has no workplace_path" do
    task = tasks(:one)
    assert_nil task.workplace_mount
  end

  test "workplace_mount returns hash when agent has workplace_path" do
    task = tasks(:one)
    task.agent.update!(workplace_path: "/workspace")

    workplace_mount = task.workplace_mount
    assert_not_nil workplace_mount
    assert workplace_mount.key?(:volume_name)
    assert workplace_mount.key?(:container_path)
    assert_equal "/workspace", workplace_mount[:container_path]
    assert_match(/summoncircle_workplace_volume_/, workplace_mount[:volume_name])
  end
end
