require "test_helper"

class RunLogProcessingTest < ActiveSupport::TestCase
  test "processes Claude JSON logs correctly" do
    task = tasks(:one)
    task.agent.update!(log_processor: "ClaudeJson")
    run = task.runs.create!(prompt: "Test")

    json_logs = '[{"type":"system","subtype":"init","session_id":"test"},{"type":"assistant","message":{"content":[{"type":"text","text":"Hello"}]}}]'

    run.send(:create_steps_from_logs, json_logs)

    assert_equal 2, run.steps.count
    assert_equal "Step::Init", run.steps.first.type
    assert_equal "Step::Text", run.steps.second.type
    assert_equal "Hello", run.steps.second.content
  end

  test "handles invalid JSON gracefully" do
    task = tasks(:one)
    task.agent.update!(log_processor: "ClaudeJson")
    run = task.runs.create!(prompt: "Test")

    invalid_json = "Not valid JSON"

    run.send(:create_steps_from_logs, invalid_json)

    assert_equal 1, run.steps.count
    assert_equal "Step::Error", run.steps.first.type
    assert_equal invalid_json, run.steps.first.content
  end

  test "processes text logs correctly" do
    task = tasks(:one)
    task.agent.update!(log_processor: "Text")
    run = task.runs.create!(prompt: "Test")

    text_logs = "Simple text output\nLine 2"

    run.send(:create_steps_from_logs, text_logs)

    assert_equal 1, run.steps.count
    assert_equal "Step::Text", run.steps.first.type
    assert_equal text_logs, run.steps.first.content
  end
end
