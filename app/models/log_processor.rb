class LogProcessor
  def self.process(logs)
    new.process(logs)
  end

  def process(logs)
    [{ raw_response: logs }]
  end
end