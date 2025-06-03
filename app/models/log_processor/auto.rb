class LogProcessor::Auto < LogProcessor
  def process(logs)
    return text_processor.process(logs) if logs.blank?

    trimmed_logs = logs.strip
    return claude_json_processor.process(trimmed_logs) if looks_like_json?(trimmed_logs)

    text_processor.process(logs)
  end

  private

  def looks_like_json?(logs)
    return false if logs.empty?

    first_char = logs[0]
    last_char = logs[-1]

    (first_char == "{" && last_char == "}") || (first_char == "[" && last_char == "]")
  end

  def text_processor
    @text_processor ||= LogProcessor::Text.new
  end

  def claude_json_processor
    @claude_json_processor ||= LogProcessor::ClaudeJson.new
  end
end
