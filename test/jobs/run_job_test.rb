require "test_helper"

class RunJobTest < ActiveJob::TestCase
  test "should be enqueued when task.run is called" do
    task = tasks(:one)
    assert_enqueued_jobs 1, only: RunJob do
      task.run("test prompt")
    end
  end
end
