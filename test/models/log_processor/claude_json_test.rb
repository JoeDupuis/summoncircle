require "test_helper"

class LogProcessor::ClaudeJsonTest < ActiveSupport::TestCase
  test "process parses JSON array into separate steps" do
    processor = LogProcessor::ClaudeJson.new
    logs = '[{"type": "system", "message": "Starting"}, {"type": "user", "content": "Hello"}, {"type": "assistant", "response": "Hi there"}]'

    result = processor.process(logs)

    assert_equal 3, result.size
    assert_equal "Step::System", result[0][:type]
    assert_equal "Step::ToolResult", result[1][:type]
    assert_equal "Step::Text", result[2][:type]
    assert_equal '{"type":"system","message":"Starting"}', result[0][:raw_response]
    assert_equal '{"type":"user","content":"Hello"}', result[1][:raw_response]
    assert_equal '{"type":"assistant","response":"Hi there"}', result[2][:raw_response]
  end

  test "process handles single JSON object" do
    processor = LogProcessor::ClaudeJson.new
    logs = '{"type": "system", "message": "Starting"}'

    result = processor.process(logs)

    assert_equal 1, result.size
    assert_equal "Step::System", result[0][:type]
    assert_equal '{"type":"system","message":"Starting"}', result[0][:raw_response]
  end

  test "process handles complex nested JSON from real example" do
    processor = LogProcessor::ClaudeJson.new
    logs = '[{"type":"system","subtype":"init","session_id":"4ae13eec-ff85-4ea2-9d98-64a7cb25e874","tools":["Task","Bash"],"mcp_servers":[]},{"type":"assistant","message":{"id":"e3d7588f-fe40-450b-a83c-c7377cbdacae","model":"<synthetic>","role":"assistant","stop_reason":"stop_sequence","stop_sequence":"","type":"message","usage":{"input_tokens":0,"output_tokens":0},"content":[{"type":"text","text":"API Error: 401"}]},"session_id":"4ae13eec-ff85-4ea2-9d98-64a7cb25e874"}]'

    result = processor.process(logs)

    assert_equal 2, result.size
    assert_equal "Step::Init", result[0][:type]
    assert_equal "Step::Text", result[1][:type]
    assert_includes result[0][:raw_response], '"type":"system"'
    assert_includes result[1][:raw_response], '"type":"assistant"'
  end

  test "process returns single step for invalid JSON" do
    processor = LogProcessor::ClaudeJson.new

    result = processor.process("Invalid JSON")
    assert_equal 1, result.size
    assert_equal({ raw_response: "Invalid JSON", type: "Step::Text", content: "Invalid JSON" }, result.first)

    result = processor.process("")
    assert_equal 1, result.size
    assert_equal({ raw_response: "", type: "Step::Text", content: "" }, result.first)
  end

  test "class method process works" do
    logs = '{"type": "test"}'
    result = LogProcessor::ClaudeJson.process(logs)

    assert_equal 1, result.size
    assert_equal "Step::Text", result.first[:type]
    assert_equal '{"type":"test"}', result.first[:raw_response]
  end

  test "process extracts tool name and inputs from tool calls" do
    processor = LogProcessor::ClaudeJson.new
    logs = '{
      "type": "assistant",
      "message": {
        "content": [
          {
            "type": "tool_use",
            "name": "WebFetch",
            "input": {
              "url": "https://example.com",
              "prompt": "What is the title?"
            }
          }
        ]
      }
    }'

    result = processor.process(logs)

    assert_equal 1, result.size
    assert_equal "Step::ToolCall", result[0][:type]
    expected_content = "name: WebFetch\ninputs: {\"url\":\"https://example.com\",\"prompt\":\"What is the title?\"}"
    assert_equal expected_content, result[0][:content]
  end
end
