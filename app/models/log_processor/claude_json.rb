class LogProcessor::ClaudeJson < LogProcessor
  def process(logs)
    begin
      parsed_array = JSON.parse(logs.strip)

      if parsed_array.is_a?(Array)
        parsed_array.map { |item| { raw_response: item } }
      else
        [ { raw_response: parsed_array } ]
      end
    rescue JSON::ParserError
      [ { raw_response: logs } ]
    end
  end
end
