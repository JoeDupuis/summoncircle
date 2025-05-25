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

  test "should have siblings through task" do
    run = runs(:one)
    assert_respond_to run, :siblings
    assert_equal 2, run.siblings.count
    assert_includes run.siblings, runs(:two)
  end

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

    # Force an error by using an invalid docker image
    run.task.agent.update!(docker_image: "nonexistent/image:notfound")

    # This should not raise an error, but should set status to failed
    assert_nothing_raised do
      run.execute!
    end

    assert run.failed?
    assert_not_nil run.started_at
    assert_not_nil run.completed_at
    assert_includes run.output, "Error:"
  end
end
