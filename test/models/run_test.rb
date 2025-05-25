require "test_helper"

class RunTest < ActiveSupport::TestCase
  test "should belong to task" do
    run = Run.new
    assert_not run.valid?
    assert_includes run.errors[:task], "must exist"
  end

  test "should have pending status by default" do
    task = tasks(:one)
    run = Run.new(task: task)
    assert run.pending?
    assert_equal "pending", run.status
  end

  test "should have valid status enum" do
    run = runs(:one)

    run.pending!
    assert run.pending?

    run.running!
    assert run.running?

    run.completed!
    assert run.completed?

    run.failed!
    assert run.failed?
  end

  test "should track is_initial flag" do
    run = runs(:one)
    assert run.is_initial

    run2 = runs(:two)
    assert_not run2.is_initial
  end
end
