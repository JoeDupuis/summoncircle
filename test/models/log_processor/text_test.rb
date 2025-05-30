require "test_helper"

class LogProcessor::TextTest < ActiveSupport::TestCase
  test "process returns single step with logs" do
    processor = LogProcessor::Text.new
    logs = "Multi-line\nlog output\nwith text"
    result = processor.process(logs)

    assert_equal 1, result.size
    assert_equal({ raw_response: logs }, result.first)
  end

  test "class method process works" do
    logs = "Test log output"
    result = LogProcessor::Text.process(logs)

    assert_equal 1, result.size
    assert_equal({ raw_response: logs }, result.first)
  end
end
