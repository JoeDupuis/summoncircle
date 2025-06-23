class Step::WriteTool < Step::ToolCall
  include LineNumberFormatting

  def file_path
    tool_inputs&.dig("file_path") || content
  end

  def file_content
    tool_inputs&.dig("content")
  end
end
