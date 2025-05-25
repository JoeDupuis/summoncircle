require "test_helper"

class RunJobTest < ActiveJob::TestCase
  test "calls execute! on the run" do
    run = runs(:one)

    # Mock the run to expect execute! to be called
    Run.expects(:find).with(run.id).returns(run)
    run.expects(:execute!)

    RunJob.perform_now(run.id)
  end
end
