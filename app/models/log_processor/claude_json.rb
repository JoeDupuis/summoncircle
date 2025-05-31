class LogProcessor::ClaudeJson < LogProcessor
  def process(logs)
    begin
      parsed_array = JSON.parse(logs.strip)

      if parsed_array.is_a?(Array)
        parsed_array.map { |item| process_item(item) }
      else
        [ process_item(parsed_array) ]
      end
    rescue JSON::ParserError
      type = error_content?(logs) ? "Step::Error" : "Step::Text"
      [ { raw_response: logs, type: type, content: logs } ]
    end
  end

  private

  def error_content?(content)
    return false if content.blank?

    content.match?(/\b(error|exception|failed|failure)\b/i) ||
      content.match?(/\d{3}\s+(error|not found|forbidden|unauthorized)/i) ||
      content.match?(/api\s+error/i)
  end

  # TODO: Refactor this to both the process_item and extract_content
  def process_item(item)
    item_json = item.to_json

    case item["type"]
    when "system"
      if item["subtype"] == "init"
        { raw_response: item_json, type: "Step::Init", content: extract_content(item) }
      else
        { raw_response: item_json, type: "Step::System", content: extract_content(item) }
      end
    when "assistant"
      if has_tool_use?(item)
        { raw_response: item_json, type: "Step::ToolCall", content: extract_content(item) }
      else
        content = extract_content(item)
        type = error_content?(content) ? "Step::Error" : "Step::Text"
        { raw_response: item_json, type: type, content: content }
      end
    when "user"
      { raw_response: item_json, type: "Step::ToolResult", content: extract_content(item) }
    when "result"
      { raw_response: item_json, type: "Step::Result", content: item["result"] || extract_content(item) }
    else
      content = extract_content(item)
      type = error_content?(content) ? "Step::Error" : "Step::Text"
      { raw_response: item_json, type: type, content: content }
    end
  end

  def has_tool_use?(item)
    return false unless item.dig("message", "content").is_a?(Array)

    item["message"]["content"].any? { |content_item| content_item["type"] == "tool_use" }
  end

  # TODO: Refactor this to both the process_item and extract_content
  def extract_content(item)
    case item["type"]
    when "system"
      if item["subtype"] == "init"
        nil
      else
        item.to_json
      end
    when "assistant"
      if item.dig("message", "content").is_a?(Array)
        if has_tool_use?(item)
          tool_use = item["message"]["content"].find { |c| c["type"] == "tool_use" }
          if tool_use
            "name: #{tool_use['name']}\ninputs: #{tool_use['input'].to_json}"
          else
            item.to_json
          end
        else
          text_content = item["message"]["content"].find { |c| c["type"] == "text" }
          text_content&.dig("text") || item.to_json
        end
      else
        item.dig("message", "content") || item.to_json
      end
    when "user"
      if item.dig("message", "content").is_a?(Array)
        item["message"]["content"].map { |c| c["content"] || c.to_json }.join("\n")
      else
        item.dig("message", "content") || item.to_json
      end
    when "result"
      item["result"] || item.to_json
    else
      item.to_json
    end
  end
end
