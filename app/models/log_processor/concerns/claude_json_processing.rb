module LogProcessor::Concerns::ClaudeJsonProcessing
  extend ActiveSupport::Concern

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
        tool_use_id = extract_tool_use_id(item)
        { raw_response: item_json, type: "Step::ToolCall", content: extract_content(item), tool_use_id: tool_use_id }
      else
        { raw_response: item_json, type: "Step::Text", content: extract_content(item) }
      end
    when "user"
      tool_use_id = extract_tool_result_id(item)
      { raw_response: item_json, type: "Step::ToolResult", content: extract_content(item), tool_use_id: tool_use_id }
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

  def extract_tool_use_id(item)
    return nil unless item.dig("message", "content").is_a?(Array)

    tool_use = item["message"]["content"].find { |c| c["type"] == "tool_use" }
    tool_use&.dig("id")
  end

  def extract_tool_result_id(item)
    return nil unless item.dig("message", "content").is_a?(Array)

    tool_result = item["message"]["content"].find { |c| c["tool_use_id"] }
    tool_result&.dig("tool_use_id")
  end
end
