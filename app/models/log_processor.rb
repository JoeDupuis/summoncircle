class LogProcessor
  ALL = [
    LogProcessor::Text,
    LogProcessor::ClaudeStreamingJson
  ].freeze

  def self.process(logs)
    new.process(logs)
  end

  def process(logs)
    [{ raw_response: logs }]
  end
end