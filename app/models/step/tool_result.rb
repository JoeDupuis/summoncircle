class Step::ToolResult < Step
  belongs_to :tool_call, class_name: "Step::ToolCall", optional: true
end
