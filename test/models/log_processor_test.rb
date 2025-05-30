require "test_helper"

class LogProcessorTest < ActiveSupport::TestCase
  test "ALL constant contains available processors" do
    assert_includes LogProcessor::ALL, LogProcessor::Text
    assert_includes LogProcessor::ALL, LogProcessor::ClaudeStreamingJson
    assert_equal 2, LogProcessor::ALL.size
  end

  test "process returns single step with logs" do
    logs = "Test log output"
    result = LogProcessor.process(logs)
    
    assert_equal 1, result.size
    assert_equal({ raw_response: logs }, result.first)
  end

  test "instance process method works" do
    processor = LogProcessor.new
    logs = "Test log output"
    result = processor.process(logs)
    
    assert_equal 1, result.size
    assert_equal({ raw_response: logs }, result.first)
  end
end