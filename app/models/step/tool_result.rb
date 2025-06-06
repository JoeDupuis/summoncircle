class Step::ToolResult < Step
  belongs_to :tool_call, class_name: "Step", optional: true

  after_create_commit :link_to_tool_call

  private

  def link_to_tool_call
    return unless respond_to?(:tool_use_id_from_raw) && tool_use_id_from_raw.present?

    # Find the corresponding tool call (ToolCall or BashTool) with matching tool_use_id in the same run
    matching_tool_call = run.steps.where(
      type: [ "Step::ToolCall", "Step::BashTool" ]
    ).find_by("raw_response LIKE ?", "%\"id\":\"#{tool_use_id_from_raw}\"%")

    if matching_tool_call
      update_column(:tool_call_id, matching_tool_call.id)
    end
  end

  def tool_use_id_from_raw
    return @tool_use_id if defined?(@tool_use_id)

    @tool_use_id = begin
      parsed = JSON.parse(raw_response)
      content_array = parsed.dig("message", "content")
      return nil unless content_array.is_a?(Array)

      tool_result = content_array.find { |c| c["tool_use_id"] }
      tool_result&.dig("tool_use_id")
    rescue JSON::ParserError
      nil
    end
  end
end
