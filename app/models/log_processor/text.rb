class LogProcessor::Text < LogProcessor
  def process(logs)
    [{ raw_response: logs }]
  end
end