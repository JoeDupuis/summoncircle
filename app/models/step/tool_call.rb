class Step::ToolCall < Step
  has_one :tool_result, class_name: "Step::ToolResult", foreign_key: :tool_call_id

  def tool_id
    parsed = parsed_response
    return nil unless parsed.is_a?(Hash)

    content_array = parsed.dig("message", "content")
    return nil unless content_array.is_a?(Array)

    tool_use = content_array.find { |c| c["type"] == "tool_use" }
    tool_use&.dig("id")
  end

  def tool_name
    parsed = parsed_response
    return nil unless parsed.is_a?(Hash)

    content_array = parsed.dig("message", "content")
    return nil unless content_array.is_a?(Array)

    tool_use = content_array.find { |c| c["type"] == "tool_use" }
    tool_use&.dig("name")
  end

  def tool_inputs
    parsed = parsed_response
    return nil unless parsed.is_a?(Hash)

    content_array = parsed.dig("message", "content")
    return nil unless content_array.is_a?(Array)

    tool_use = content_array.find { |c| c["type"] == "tool_use" }
    tool_use&.dig("input")
  end


  def pending?
    tool_result.nil?
  end
end
