class LogProcessor::ClaudeStreamingJson < LogProcessor
  def process(logs)
    logs.strip.split("\n").filter_map do |line|
      next if line.strip.empty?

      begin
        parsed_item = JSON.parse(line.strip)
        process_item(parsed_item)
      rescue JSON::ParserError
        { raw_response: line, type: "Step::Error", content: line }
      end
    end
  end

  private

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
        { raw_response: item_json, type: "Step::Text", content: extract_content(item) }
      end
    when "user"
      { raw_response: item_json, type: "Step::ToolResult", content: extract_content(item) }
    when "result"
      { raw_response: item_json, type: "Step::Result", content: item["result"] || extract_content(item) }
    else
      { raw_response: item_json, type: "Step::Text", content: extract_content(item) }
    end
  end

  def has_tool_use?(item)
    return false unless item.dig("message", "content").is_a?(Array)

    item["message"]["content"].any? { |content_item| content_item["type"] == "tool_use" }
  end

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
