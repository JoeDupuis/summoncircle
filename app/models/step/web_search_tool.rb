class Step::WebSearchTool < Step::ToolCall
  def query
    tool_inputs&.dig("query")
  end
end
