class Step::BashTool < Step::ToolCall
  def command
    tool_inputs&.dig("command") || content
  end

  def delete_operation?
    return false unless command

    # Check for common delete commands
    command.match?(/^(rm|rmdir|del|delete)\s+/) ||
      command.match?(/^(rm|rmdir)\s+-[rf]+\s+/)
  end

  def deleted_path
    return nil unless delete_operation?

    # Extract the path from common delete commands
    if match = command.match(/^(?:rm|rmdir|del|delete)\s+(?:-[rf]+\s+)?(.+)$/)
      match[1].strip
    end
  end
end
