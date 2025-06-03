class LogProcessor
  ALL = [
    LogProcessor::Text,
    LogProcessor::ClaudeJson
  ].freeze

  def self.process(logs)
    new.process(logs)
  end

  def process(logs)
    raise NotImplementedError, "Subclasses must implement #process"
  end
end
