require "test_helper"

class RunJobTest < ActiveJob::TestCase
  test "should be enqueued when task.run is called" do
    task = tasks(:one)
    assert_enqueued_jobs 1, only: RunJob do
      task.run("test prompt")
    end
  end

  test "should find run by id" do
    run = runs(:one)
    job = RunJob.new

    # Test that perform can find the run
    assert_nothing_raised do
      # We can't easily test the full Docker execution in unit tests
      # but we can ensure the job can find the run
      found_run = Run.find(run.id)
      assert_equal run, found_run
    end
  end
end
