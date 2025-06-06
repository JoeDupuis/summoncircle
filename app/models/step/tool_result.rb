class Step::ToolResult < Step
  belongs_to :tool_call, class_name: "Step", optional: true

  after_create_commit :link_to_tool_call

  private

  def link_to_tool_call
    return unless respond_to?(:tool_use_id) && tool_use_id.present?

    matching_tool_call = run.steps.where(
      type: [ "Step::ToolCall", "Step::BashTool" ],
      tool_use_id: tool_use_id
    ).first

    if matching_tool_call
      update_column(:tool_call_id, matching_tool_call.id)
    end
  end
end
