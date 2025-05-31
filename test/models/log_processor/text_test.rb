require "test_helper"

class LogProcessor::TextTest < ActiveSupport::TestCase
  test "process returns single step with normal logs" do
    processor = LogProcessor::Text.new
    logs = "Multi-line\nlog output\nwith text"
    result = processor.process(logs)

    assert_equal 1, result.size
    assert_equal({ raw_response: logs, type: "Step::Text", content: logs }, result.first)
  end

  test "process returns Step::Error for error content" do
    processor = LogProcessor::Text.new
    logs = "API Error: 401 Unauthorized"
    result = processor.process(logs)

    assert_equal 1, result.size
    assert_equal({ raw_response: logs, type: "Step::Error", content: logs }, result.first)
  end

  test "process detects various error patterns" do
    processor = LogProcessor::Text.new

    error_cases = [
      "Error: Something went wrong",
      "Exception occurred in method",
      "Process failed with code 1",
      "Task failure detected",
      "404 Not Found",
      "500 Error",
      "403 Forbidden",
      "401 Unauthorized",
      "API Error: Invalid token"
    ]

    error_cases.each do |error_content|
      result = processor.process(error_content)
      assert_equal "Step::Error", result.first[:type], "Expected '#{error_content}' to be detected as error"
    end
  end

  test "process does not falsely detect errors" do
    processor = LogProcessor::Text.new

    normal_cases = [
      "This is normal log content",
      "Processing completed successfully",
      "Starting task execution",
      "200 OK",
      "Successfully authenticated"
    ]

    normal_cases.each do |normal_content|
      result = processor.process(normal_content)
      assert_equal "Step::Text", result.first[:type], "Expected '#{normal_content}' to be detected as normal text"
    end
  end

  test "class method process works" do
    logs = "Test log output"
    result = LogProcessor::Text.process(logs)

    assert_equal 1, result.size
    assert_equal({ raw_response: logs, type: "Step::Text", content: logs }, result.first)
  end
end
