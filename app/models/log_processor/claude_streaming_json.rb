class LogProcessor::ClaudeStreamingJson < LogProcessor
  def process(logs)
    steps = []

    logs.split("\n").each do |line|
      line = line.strip
      next if line.empty?

      begin
        parsed_json = JSON.parse(line)
        steps << { raw_response: parsed_json }
      rescue JSON::ParserError
        steps << { raw_response: line }
      end
    end

    steps.empty? ? [ { raw_response: logs } ] : steps
  end
end
