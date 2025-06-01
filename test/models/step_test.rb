require "test_helper"

class StepTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    step = Step.new(
      run: runs(:one),
      raw_response: "Hello"
    )
    assert step.valid?
  end

  test "should require run" do
    step = Step.new(raw_response: "text")
    assert_not step.valid?
    assert_includes step.errors[:run], "must exist"
  end

  test "should require raw_response" do
    step = Step.new(run: runs(:one))
    assert_not step.valid?
    assert_includes step.errors[:raw_response], "can't be blank"
  end

  test "run should have many steps" do
    run = runs(:one)
    assert_respond_to run, :steps
    assert_kind_of ActiveRecord::Associations::CollectionProxy, run.steps
  end

  test "destroying run should destroy associated steps" do
    run = runs(:one)
    initial_step_count = run.steps.count
    step = Step.create!(
      run: run,
      raw_response: "Test"
    )

    assert_difference "Step.count", -(initial_step_count + 1) do
      run.destroy
    end
  end

  test "parsed_response should return parsed JSON" do
    json_data = { "message" => "hello", "status" => "success" }
    step = Step.new(
      run: runs(:one),
      raw_response: json_data.to_json
    )

    assert_equal json_data, step.parsed_response
  end

  test "parsed_response should return raw_response for invalid JSON" do
    step = Step.new(
      run: runs(:one),
      raw_response: "invalid json"
    )

    assert_equal "invalid json", step.parsed_response
  end

  test "has many repo_states" do
    step = steps(:one)
    assert_respond_to step, :repo_states
    assert_kind_of ActiveRecord::Associations::CollectionProxy, step.repo_states
  end

  test "destroying step should destroy associated repo_states" do
    step = steps(:one)
    initial_repo_states_count = step.repo_states.count

    assert_difference "RepoState.count", -initial_repo_states_count do
      step.destroy
    end
  end
end
