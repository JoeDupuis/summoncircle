class LogProcessor::Text < LogProcessor
  def process(logs)
    type = error_content?(logs) ? "Step::Error" : "Step::Text"
    [ { raw_response: logs, type: type, content: logs } ]
  end

  private

  def error_content?(content)
    return false if content.blank?

    content.match?(/\b(error|exception|failed|failure)\b/i) ||
      content.match?(/\d{3}\s+(error|not found|forbidden|unauthorized)/i) ||
      content.match?(/api\s+error/i)
  end
end
