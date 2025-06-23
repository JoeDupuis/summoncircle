class Step::EditTool < Step::ToolCall
  include LineNumberFormatting

  def file_path
    tool_inputs&.dig("file_path") || content
  end

  def old_string
    tool_inputs&.dig("old_string")
  end

  def new_string
    tool_inputs&.dig("new_string")
  end

  def replace_all?
    tool_inputs&.dig("replace_all") == true
  end
end
