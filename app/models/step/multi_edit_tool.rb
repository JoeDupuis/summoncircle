class Step::MultiEditTool < Step::ToolCall
  include LineNumberFormatting

  def file_path
    tool_inputs&.dig("file_path") || content
  end

  def edits
    tool_inputs&.dig("edits") || []
  end
end
