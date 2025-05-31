class LogProcessor::Text < LogProcessor
  def process(logs)
    [ { raw_response: logs, type: "Step::Text", content: logs } ]
  end
end
