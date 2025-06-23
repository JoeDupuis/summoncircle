class Step::ReadTool < Step::ToolCall
  include LineNumberFormatting

  def file_path
    tool_inputs&.dig("file_path") || content
  end
end
