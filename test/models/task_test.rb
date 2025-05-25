require "test_helper"

class TaskTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  test "should belong to project and agent" do
    task = Task.new
    assert_not task.valid?
    assert_includes task.errors[:project], "must exist"
    assert_includes task.errors[:agent], "must exist"
  end

  test "should have many runs" do
    task = tasks(:one)
    assert_respond_to task, :runs
    assert_equal 2, task.runs.count
  end

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
end
