require "test_helper"

class Step::ErrorTest < ActiveSupport::TestCase
  test "Step::Error inherits from Step" do
    assert Step::Error < Step
  end

  test "can create Step::Error instance" do
    run = runs(:one)
    step = Step::Error.create!(
      run: run,
      raw_response: '{"error": "Something went wrong"}',
      content: "Error: Something went wrong"
    )

    assert step.persisted?
    assert_equal "Step::Error", step.type
    assert_equal "Error: Something went wrong", step.content
  end
end
