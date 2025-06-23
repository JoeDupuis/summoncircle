class Step::BashTool < Step::ToolCall
  def command
    tool_inputs&.dig("command") || content
  end
end
