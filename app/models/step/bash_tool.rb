class Step::BashTool < Step
  has_one :tool_result, class_name: "Step::ToolResult", foreign_key: :tool_call_id

  def pending?
    tool_result.nil?
  end
end
