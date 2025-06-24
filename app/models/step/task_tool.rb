class Step::TaskTool < Step::ToolCall
  def description
    tool_inputs&.dig("description")
  end

  def prompt
    tool_inputs&.dig("prompt")
  end
end
