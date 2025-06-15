class LogProcessor::Text < LogProcessor
  def process(logs)
    [
      { raw_response: logs, type: "Step::Text", content: logs },
      { raw_response: logs, type: "Step::Result", content: logs }
    ]
  end
end
