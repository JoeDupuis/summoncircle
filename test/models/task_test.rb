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

  test "workplace_mount returns VolumeMount when agent has workplace_path" do
    task = tasks(:one)

    workplace_mount = task.workplace_mount
    assert_not_nil workplace_mount
    assert_instance_of VolumeMount, workplace_mount
    assert_nil workplace_mount.volume
    assert_equal task, workplace_mount.task
    assert_match(/summoncircle_workplace_volume_/, workplace_mount.volume_name)
  end
end
