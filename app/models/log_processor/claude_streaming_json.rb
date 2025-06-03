class LogProcessor::ClaudeStreamingJson < LogProcessor
  include LogProcessor::Concerns::ClaudeJsonProcessing

  def process(logs)
    logs.strip.split("\n").filter_map do |line|
      next if line.strip.empty?

      begin
        parsed_item = JSON.parse(line.strip)
        process_item(parsed_item)
      rescue JSON::ParserError
        { raw_response: line, type: "Step::Error", content: line }
      end
    end
  end
end
