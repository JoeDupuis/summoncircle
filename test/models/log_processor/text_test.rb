require "test_helper"

class LogProcessor::TextTest < ActiveSupport::TestCase
  test "process returns text and result steps" do
    processor = LogProcessor::Text.new
    logs = "Multi-line\nlog output\nwith text"
    result = processor.process(logs)

    assert_equal 2, result.size
    assert_equal({ raw_response: logs, type: "Step::Text", content: logs }, result[0])
    assert_equal({ raw_response: logs, type: "Step::Result", content: logs }, result[1])
  end

  test "class method process works" do
    logs = "Test log output"
    result = LogProcessor::Text.process(logs)

    assert_equal 2, result.size
    assert_equal({ raw_response: logs, type: "Step::Text", content: logs }, result[0])
    assert_equal({ raw_response: logs, type: "Step::Result", content: logs }, result[1])
  end
end
