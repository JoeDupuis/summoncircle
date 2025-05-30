require "test_helper"

class LogProcessor::ClaudeStreamingJsonTest < ActiveSupport::TestCase
  test "process parses valid JSON lines into separate steps" do
    processor = LogProcessor::ClaudeStreamingJson.new
    logs = '{"type": "system", "message": "Starting"}
{"type": "user", "content": "Hello"}
{"type": "assistant", "response": "Hi there"}'
    
    result = processor.process(logs)
    
    assert_equal 3, result.size
    assert_equal({ raw_response: { "type" => "system", "message" => "Starting" } }, result[0])
    assert_equal({ raw_response: { "type" => "user", "content" => "Hello" } }, result[1])
    assert_equal({ raw_response: { "type" => "assistant", "response" => "Hi there" } }, result[2])
  end

  test "process handles mixed valid and invalid JSON lines" do
    processor = LogProcessor::ClaudeStreamingJson.new
    logs = '{"type": "system"}
Invalid JSON line
{"type": "user", "content": "Hello"}'
    
    result = processor.process(logs)
    
    assert_equal 3, result.size
    assert_equal({ raw_response: { "type" => "system" } }, result[0])
    assert_equal({ raw_response: "Invalid JSON line" }, result[1])
    assert_equal({ raw_response: { "type" => "user", "content" => "Hello" } }, result[2])
  end

  test "process handles empty lines" do
    processor = LogProcessor::ClaudeStreamingJson.new
    logs = '{"type": "system"}

{"type": "user"}'
    
    result = processor.process(logs)
    
    assert_equal 2, result.size
    assert_equal({ raw_response: { "type" => "system" } }, result[0])
    assert_equal({ raw_response: { "type" => "user" } }, result[1])
  end

  test "process returns single step for empty or invalid logs" do
    processor = LogProcessor::ClaudeStreamingJson.new
    
    result = processor.process("")
    assert_equal 1, result.size
    assert_equal({ raw_response: "" }, result.first)
    
    result = processor.process("   \n  \n  ")
    assert_equal 1, result.size
    assert_equal({ raw_response: "   \n  \n  " }, result.first)
  end

  test "class method process works" do
    logs = '{"type": "test"}'
    result = LogProcessor::ClaudeStreamingJson.process(logs)
    
    assert_equal 1, result.size
    assert_equal({ raw_response: { "type" => "test" } }, result.first)
  end
end