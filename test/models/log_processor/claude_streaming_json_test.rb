require "test_helper"

class LogProcessor::ClaudeStreamingJsonTest < ActiveSupport::TestCase
  def setup
    @processor = LogProcessor::ClaudeStreamingJson.new
  end

  test "processes multiple JSON objects separated by newlines" do
    logs = '{"type": "system", "subtype": "init"}
{"type": "assistant", "message": {"content": "Hello"}}
{"type": "result", "result": "Done"}'

    steps = @processor.process(logs)

    assert_equal 3, steps.length
    assert_equal "Step::Init", steps[0][:type]
    assert_equal "Step::Text", steps[1][:type]
    assert_equal "Hello", steps[1][:content]
    assert_equal "Step::Result", steps[2][:type]
    assert_equal "Done", steps[2][:content]
  end

  test "handles empty lines gracefully" do
    logs = '{"type": "system", "subtype": "init"}

{"type": "assistant", "message": {"content": "Hello"}}'

    steps = @processor.process(logs)

    assert_equal 2, steps.length
    assert_equal "Step::Init", steps[0][:type]
    assert_equal "Step::Text", steps[1][:type]
  end

  test "handles malformed JSON lines" do
    logs = '{"type": "system", "subtype": "init"}
{invalid json}
{"type": "assistant", "message": {"content": "Hello"}}'

    steps = @processor.process(logs)

    assert_equal 3, steps.length
    assert_equal "Step::Init", steps[0][:type]
    assert_equal "Step::Error", steps[1][:type]
    assert_equal "Step::Text", steps[2][:type]
  end

  test "processes tool use correctly" do
    logs = '{"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "bash", "input": {"command": "ls"}}]}}'

    steps = @processor.process(logs)

    assert_equal 1, steps.length
    assert_equal "Step::ToolCall", steps[0][:type]
    assert_includes steps[0][:content], "name: bash"
  end

  test "processes Bash tool calls as Step::BashTool" do
    logs = '{"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Bash", "input": {"command": "ls -la", "description": "List files"}}]}}'

    steps = @processor.process(logs)

    assert_equal 1, steps.length
    assert_equal "Step::BashTool", steps[0][:type]
    assert_equal "ls -la", steps[0][:content]
  end

  test "processes tool results correctly" do
    logs = '{"type": "user", "message": {"content": [{"content": "file1.txt\nfile2.txt"}]}}'

    steps = @processor.process(logs)

    assert_equal 1, steps.length
    assert_equal "Step::ToolResult", steps[0][:type]
    assert_equal "file1.txt\nfile2.txt", steps[0][:content]
  end
end
