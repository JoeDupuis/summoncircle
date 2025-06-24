class Step::WebFetchTool < Step::ToolCall
  def url
    tool_inputs&.dig("url")
  end

  def prompt
    tool_inputs&.dig("prompt")
  end
end
