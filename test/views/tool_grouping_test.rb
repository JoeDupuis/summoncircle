require "test_helper"

class ToolGroupingTest < ActionView::TestCase
  include ApplicationHelper

  test "tool result is rendered inside its corresponding tool call" do
    run = runs(:one)

    # Create a tool call step
    tool_call = run.steps.create!(
      type: "Step::ToolCall",
      raw_response: {
        type: "assistant",
        message: {
          content: [
            {
              type: "tool_use",
              id: "toolu_test123",
              name: "TestTool",
              input: { test: "data" }
            }
          ]
        }
      }.to_json,
      content: "name: TestTool\ninputs: {\"test\":\"data\"}"
    )

    # Create corresponding tool result
    tool_result = run.steps.create!(
      type: "Step::ToolResult",
      tool_call_id: tool_call.id,
      raw_response: {
        type: "user",
        message: {
          content: [
            {
              tool_use_id: "toolu_test123",
              type: "tool_result",
              content: "Test result output"
            }
          ]
        }
      }.to_json,
      content: "Test result output"
    )

    # Render the tool call partial
    html = render partial: "step/tool_calls/tool_call", locals: { tool_call: tool_call }

    # Check that tool call is rendered
    assert_match /Tool Call: TestTool/, html
    assert_match /name: TestTool/, html

    # Check that tool result is rendered inside tool call
    assert_match /Test result output/, html
    assert_match /Tool Result/, html

    # Check that the pending spinner is not shown
    assert_no_match /Waiting for result/, html
  end

  test "tool call shows pending spinner when no result available" do
    run = runs(:one)

    # Create a tool call step without result
    tool_call = run.steps.create!(
      type: "Step::ToolCall",
      raw_response: {
        type: "assistant",
        message: {
          content: [
            {
              type: "tool_use",
              id: "toolu_test456",
              name: "PendingTool",
              input: { test: "data" }
            }
          ]
        }
      }.to_json,
      content: "name: PendingTool\ninputs: {\"test\":\"data\"}"
    )

    # Render the tool call partial
    html = render partial: "step/tool_calls/tool_call", locals: { tool_call: tool_call }

    # Check that tool call is rendered
    assert_match /Tool Call: PendingTool/, html

    # Check that pending spinner is shown
    assert_match /Waiting for result/, html
    assert_match /tool-result-pending/, html
    assert_match /spinner/, html
  end
end
