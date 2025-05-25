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
