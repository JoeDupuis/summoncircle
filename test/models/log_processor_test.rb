require "test_helper"

class LogProcessorTest < ActiveSupport::TestCase
  test "class process method raises NotImplementedError" do
    logs = "Test log output"
    assert_raises(NotImplementedError) do
      LogProcessor.process(logs)
    end
  end

  test "instance process method raises NotImplementedError" do
    processor = LogProcessor.new
    logs = "Test log output"
    assert_raises(NotImplementedError) do
      processor.process(logs)
    end
  end
end
