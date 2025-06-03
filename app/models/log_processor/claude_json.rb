class LogProcessor::ClaudeJson < LogProcessor
  include LogProcessor::Concerns::ClaudeJsonProcessing

  def process(logs)
    begin
      parsed_array = JSON.parse(logs.strip)

      if parsed_array.is_a?(Array)
        parsed_array.map { |item| process_item(item) }
      else
        [ process_item(parsed_array) ]
      end
    rescue JSON::ParserError
      [ { raw_response: logs, type: "Step::Error", content: logs } ]
    end
  end
end
