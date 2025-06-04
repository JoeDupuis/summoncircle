class Step::BashCommand < Step::ToolCall
  def command
    parsed_inputs["command"]
  end

  def description
    parsed_inputs["description"]
  end

  private

  def parsed_inputs
    @parsed_inputs ||= begin
      lines = content.split("\n")
      inputs_json = lines[1]&.gsub(/^inputs: /, "") || "{}"
      JSON.parse(inputs_json)
    rescue JSON::ParserError
      {}
    end
  end
end
