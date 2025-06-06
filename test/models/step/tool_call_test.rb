require "test_helper"

class Step::ToolCallTest < ActiveSupport::TestCase
  test "extracts tool name from raw response" do
    run = runs(:one)
    tool_call = Step::ToolCall.create!(
      run: run,
      raw_response: {
        type: "assistant",
        message: {
          content: [
            {
              type: "tool_use",
              id: "toolu_01ABC123",
              name: "WebFetch",
              input: {
                url: "https://example.com",
                prompt: "What is the title?"
              }
            }
          ]
        }
      }.to_json,
      content: "name: WebFetch\ninputs: {}"
    )

    assert_equal "WebFetch", tool_call.tool_name
  end

  test "extracts tool inputs from raw response" do
    run = runs(:one)
    tool_call = Step::ToolCall.create!(
      run: run,
      raw_response: {
        type: "assistant",
        message: {
          content: [
            {
              type: "tool_use",
              id: "toolu_01ABC123",
              name: "WebFetch",
              input: {
                url: "https://example.com",
                prompt: "What is the title?"
              }
            }
          ]
        }
      }.to_json,
      content: "name: WebFetch\ninputs: {}"
    )

    expected_inputs = {
      "url" => "https://example.com",
      "prompt" => "What is the title?"
    }
    assert_equal expected_inputs, tool_call.tool_inputs
  end

  test "extracts tool id from raw response" do
    run = runs(:one)
    tool_call = Step::ToolCall.create!(
      run: run,
      raw_response: {
        type: "assistant",
        message: {
          content: [
            {
              type: "tool_use",
              id: "toolu_01ABC123",
              name: "WebFetch",
              input: {
                url: "https://example.com",
                prompt: "What is the title?"
              }
            }
          ]
        }
      }.to_json,
      content: "name: WebFetch\ninputs: {}"
    )

    assert_equal "toolu_01ABC123", tool_call.tool_id
  end

  test "returns nil when raw response is not properly structured" do
    run = runs(:one)
    tool_call = Step::ToolCall.create!(
      run: run,
      raw_response: "Invalid JSON",
      content: "Error content"
    )

    assert_nil tool_call.tool_name
    assert_nil tool_call.tool_inputs
    assert_nil tool_call.tool_id
  end

  test "returns nil when no tool_use in content" do
    run = runs(:one)
    tool_call = Step::ToolCall.create!(
      run: run,
      raw_response: {
        type: "assistant",
        message: {
          content: [
            {
              type: "text",
              text: "Just some text"
            }
          ]
        }
      }.to_json,
      content: "Just text"
    )

    assert_nil tool_call.tool_name
    assert_nil tool_call.tool_inputs
    assert_nil tool_call.tool_id
  end
end
