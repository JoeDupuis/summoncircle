class Step::LsTool < Step::ToolCall
  def path
    tool_inputs&.dig("path") || content
  end
end
