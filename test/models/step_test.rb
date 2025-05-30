require "test_helper"

class StepTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    step = Step.new(
      run: runs(:one),
      raw_response: { type: "text", text: "Hello" }
    )
    assert step.valid?
  end

  test "should require run" do
    step = Step.new(raw_response: { type: "text" })
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
      raw_response: { type: "text", text: "Test" }
    )

    assert_difference "Step.count", -(initial_step_count + 1) do
      run.destroy
    end
  end
end
