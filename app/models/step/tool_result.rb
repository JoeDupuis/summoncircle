class Step::ToolResult < Step
  def tool_call
    return nil unless tool_use_id.present?

    run.steps.where(type: "Step::ToolCall", tool_use_id: tool_use_id).first
  end
end
