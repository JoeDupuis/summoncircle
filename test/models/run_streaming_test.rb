require "test_helper"

class RunStreamingTest < ActiveSupport::TestCase
  def setup
    @agent = agents(:with_claude_json_processor)
    @agent.update!(log_processor: "ClaudeStreamingJson")

    @task = tasks(:with_claude_json_processor)
    @run = @task.runs.create!(prompt: "Test streaming")
  end

  test "identifies streaming agent correctly" do
    # Test streaming agent
    assert_equal "ClaudeStreamingJson", @task.agent.log_processor

    # Test non-streaming agent
    @task.agent.update!(log_processor: "ClaudeJson")
    @task.agent.reload
    assert_equal "ClaudeJson", @task.agent.log_processor
  end

  test "streaming processor handles line-by-line JSON" do
    streaming_logs = '{"type": "system", "subtype": "init"}
{"type": "assistant", "message": {"content": "Processing..."}}
{"type": "result", "result": "Complete"}'

    processor = LogProcessor::ClaudeStreamingJson.new
    steps = processor.process(streaming_logs)

    assert_equal 3, steps.length
    assert_equal "Step::Init", steps[0][:type]
    assert_equal "Step::Text", steps[1][:type]
    assert_equal "Step::Result", steps[2][:type]
    assert_equal "Complete", steps[2][:content]
  end

  test "streaming processor handles malformed lines gracefully" do
    streaming_logs = '{"type": "system", "subtype": "init"}
{malformed json
{"type": "assistant", "message": {"content": "Processing..."}}'

    processor = LogProcessor::ClaudeStreamingJson.new
    steps = processor.process(streaming_logs)

    assert_equal 3, steps.length
    assert_equal "Step::Init", steps[0][:type]
    assert_equal "Step::Error", steps[1][:type]
    assert_equal "Step::Text", steps[2][:type]
  end

  test "streaming processor extracts tool use content correctly" do
    tool_use_json = '{"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "bash", "input": {"command": "echo hello"}}]}}'

    processor = LogProcessor::ClaudeStreamingJson.new
    steps = processor.process(tool_use_json)

    assert_equal 1, steps.length
    assert_equal "Step::ToolCall", steps[0][:type]
    assert_includes steps[0][:content], "name: bash"
    assert_includes steps[0][:content], "echo hello"
  end

  test "streaming processor extracts tool result content correctly" do
    tool_result_json = '{"type": "user", "message": {"content": [{"content": "hello\\nworld"}]}}'

    processor = LogProcessor::ClaudeStreamingJson.new
    steps = processor.process(tool_result_json)

    assert_equal 1, steps.length
    assert_equal "Step::ToolResult", steps[0][:type]
    assert_equal "hello\nworld", steps[0][:content]
  end
end
