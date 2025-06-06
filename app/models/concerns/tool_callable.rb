module ToolCallable
  extend ActiveSupport::Concern

  included do
    has_one :tool_result, class_name: "Step::ToolResult", foreign_key: :tool_call_id
  end

  def pending?
    tool_result.nil?
  end
end
