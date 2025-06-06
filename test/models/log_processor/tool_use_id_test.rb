require "test_helper"

class LogProcessor::ToolUseIdTest < ActiveSupport::TestCase
  test "captures tool_use_id for tool calls" do
    processor = LogProcessor::ClaudeJson.new
    logs = [
      {
        type: "assistant",
        message: {
          content: [
            {
              type: "tool_use",
              id: "toolu_01ABC123",
              name: "Bash",
              input: { command: "ls" }
            }
          ]
        }
      }
    ].to_json

    result = processor.process(logs)

    assert_equal 1, result.length
    assert_equal "Step::ToolCall", result.first[:type]
    assert_equal "toolu_01ABC123", result.first[:tool_use_id]
  end

  test "captures tool_use_id for tool results" do
    processor = LogProcessor::ClaudeJson.new
    logs = [
      {
        type: "user",
        message: {
          content: [
            {
              tool_use_id: "toolu_01ABC123",
              type: "tool_result",
              content: "file1.txt\nfile2.txt"
            }
          ]
        }
      }
    ].to_json

    result = processor.process(logs)

    assert_equal 1, result.length
    assert_equal "Step::ToolResult", result.first[:type]
    assert_equal "toolu_01ABC123", result.first[:tool_use_id]
  end

  test "processes parallel tool calls correctly" do
    processor = LogProcessor::ClaudeJson.new
    logs = [
      {
        type: "assistant",
        message: {
          content: [
            {
              type: "tool_use",
              id: "toolu_01ABC123",
              name: "Bash",
              input: { command: "ls" }
            }
          ]
        }
      },
      {
        type: "assistant",
        message: {
          content: [
            {
              type: "tool_use",
              id: "toolu_01DEF456",
              name: "Bash",
              input: { command: "pwd" }
            }
          ]
        }
      },
      {
        type: "user",
        message: {
          content: [
            {
              tool_use_id: "toolu_01ABC123",
              type: "tool_result",
              content: "file1.txt"
            }
          ]
        }
      },
      {
        type: "user",
        message: {
          content: [
            {
              tool_use_id: "toolu_01DEF456",
              type: "tool_result",
              content: "/home/user"
            }
          ]
        }
      }
    ].to_json

    result = processor.process(logs)

    assert_equal 4, result.length

    # First tool call
    assert_equal "Step::ToolCall", result[0][:type]
    assert_equal "toolu_01ABC123", result[0][:tool_use_id]

    # Second tool call
    assert_equal "Step::ToolCall", result[1][:type]
    assert_equal "toolu_01DEF456", result[1][:tool_use_id]

    # First tool result
    assert_equal "Step::ToolResult", result[2][:type]
    assert_equal "toolu_01ABC123", result[2][:tool_use_id]

    # Second tool result
    assert_equal "Step::ToolResult", result[3][:type]
    assert_equal "toolu_01DEF456", result[3][:tool_use_id]
  end
end
