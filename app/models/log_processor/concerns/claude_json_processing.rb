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
      if has_thinking?(item)
        { raw_response: item_json, type: "Step::Thinking", content: extract_content(item) }
      elsif has_tool_use?(item)
        tool_use_id = extract_tool_use_id(item)
        tool_use = item["message"]["content"].find { |c| c["type"] == "tool_use" }
        if tool_use && tool_use["name"] == "Bash"
          { raw_response: item_json, type: "Step::BashTool", content: extract_content(item), tool_use_id: tool_use_id }
        elsif tool_use && tool_use["name"] == "TodoWrite"
          { raw_response: item_json, type: "Step::TodoWrite", content: extract_content(item), tool_use_id: tool_use_id }
        elsif tool_use && tool_use["name"] == "Read"
          { raw_response: item_json, type: "Step::ReadTool", content: extract_content(item), tool_use_id: tool_use_id }
        elsif tool_use && tool_use["name"] == "Edit"
          { raw_response: item_json, type: "Step::EditTool", content: extract_content(item), tool_use_id: tool_use_id }
        elsif tool_use && tool_use["name"] == "MultiEdit"
          { raw_response: item_json, type: "Step::MultiEditTool", content: extract_content(item), tool_use_id: tool_use_id }
        elsif tool_use && tool_use["name"] == "Write"
          { raw_response: item_json, type: "Step::WriteTool", content: extract_content(item), tool_use_id: tool_use_id }
        elsif tool_use && tool_use["name"] == "Glob"
          { raw_response: item_json, type: "Step::GlobTool", content: extract_content(item), tool_use_id: tool_use_id }
        elsif tool_use && tool_use["name"] == "Grep"
          { raw_response: item_json, type: "Step::GrepTool", content: extract_content(item), tool_use_id: tool_use_id }
        elsif tool_use && tool_use["name"] == "LS"
          { raw_response: item_json, type: "Step::LsTool", content: extract_content(item), tool_use_id: tool_use_id }
        elsif tool_use && tool_use["name"] == "WebFetch"
          { raw_response: item_json, type: "Step::WebFetchTool", content: extract_content(item), tool_use_id: tool_use_id }
        elsif tool_use && tool_use["name"] == "WebSearch"
          { raw_response: item_json, type: "Step::WebSearchTool", content: extract_content(item), tool_use_id: tool_use_id }
        else
          { raw_response: item_json, type: "Step::ToolCall", content: extract_content(item), tool_use_id: tool_use_id }
        end
      else
        { raw_response: item_json, type: "Step::Text", content: extract_content(item) }
      end
    when "user"
      tool_use_id = extract_tool_result_id(item)
      { raw_response: item_json, type: "Step::ToolResult", content: extract_content(item), tool_use_id: tool_use_id }
    when "result"
      step_data = { raw_response: item_json, type: "Step::Result", content: item["result"] || extract_content(item) }
      if item["total_cost_usd"]
        step_data[:cost_usd] = item["total_cost_usd"]
      end
      if item["usage"]
        step_data[:input_tokens] = item["usage"]["input_tokens"]
        step_data[:output_tokens] = item["usage"]["output_tokens"]
        step_data[:cache_creation_tokens] = item["usage"]["cache_creation_input_tokens"]
        step_data[:cache_read_tokens] = item["usage"]["cache_read_input_tokens"]
      end
      step_data
    else
      { raw_response: item_json, type: "Step::Text", content: extract_content(item) }
    end
  end

  def has_thinking?(item)
    return false unless item.dig("message", "content").is_a?(Array)

    item["message"]["content"].any? { |content_item| content_item["type"] == "thinking" }
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
        if has_thinking?(item)
          thinking_content = item["message"]["content"].find { |c| c["type"] == "thinking" }
          thinking_content&.dig("thinking") || item.to_json
        elsif has_tool_use?(item)
          tool_use = item["message"]["content"].find { |c| c["type"] == "tool_use" }
          if tool_use
            if tool_use["name"] == "Bash"
              tool_use["input"]["command"]
            elsif tool_use["name"] == "TodoWrite"
              "Todo list updated"
            elsif tool_use["name"] == "Read"
              tool_use["input"]["file_path"] || tool_use["input"].to_json
            elsif tool_use["name"] == "Edit"
              tool_use["input"]["file_path"] || tool_use["input"].to_json
            elsif tool_use["name"] == "MultiEdit"
              tool_use["input"]["file_path"] || tool_use["input"].to_json
            elsif tool_use["name"] == "Write"
              tool_use["input"]["file_path"] || tool_use["input"].to_json
            elsif tool_use["name"] == "Glob"
              tool_use["input"]["pattern"] || tool_use["input"].to_json
            elsif tool_use["name"] == "Grep"
              tool_use["input"]["pattern"] || tool_use["input"].to_json
            elsif tool_use["name"] == "LS"
              tool_use["input"]["path"] || tool_use["input"].to_json
            elsif tool_use["name"] == "WebFetch"
              tool_use["input"]["url"] || tool_use["input"].to_json
            elsif tool_use["name"] == "WebSearch"
              tool_use["input"]["query"] || tool_use["input"].to_json
            else
              "name: #{tool_use['name']}\ninputs: #{tool_use['input'].to_json}"
            end
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
