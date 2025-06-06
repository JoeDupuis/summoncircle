class LogProcessor
  ALL = [
    LogProcessor::Text,
    LogProcessor::ClaudeJson,
    LogProcessor::ClaudeStreamingJson
  ].freeze

  def self.process(logs)
    new.process(logs)
  end

  def process(logs)
    raise NotImplementedError, "Subclasses must implement #process"
  end

  def process_container(container, run)
    # Default behavior: wait for container, get logs, process them
    container.wait
    logs = container.logs(stdout: true, stderr: true)
    # Docker logs prefix each line with 8 bytes of metadata that we need to strip
    clean_logs = logs.gsub(/^.{8}/m, "").force_encoding("UTF-8").scrub.strip

    # Process logs and create steps with relationships
    step_data_list = process(clean_logs)
    create_steps_with_relationships(run, step_data_list)
  end

  private

  def create_steps_with_relationships(run, step_data_list)
    tool_call_map = {}
    
    step_data_list.each do |step_data|
      if (step_data[:type] == "Step::ToolCall" || step_data[:type] == "Step::BashTool") && step_data[:tool_use_id]
        # Create tool call/bash tool and store mapping
        step = run.steps.create!(step_data.except(:tool_use_id))
        tool_call_map[step_data[:tool_use_id]] = step.id
      elsif step_data[:type] == "Step::ToolResult" && step_data[:tool_use_id]
        # Find matching tool call and set foreign key
        tool_call_id = tool_call_map[step_data[:tool_use_id]]
        step_data_clean = step_data.except(:tool_use_id)
        step_data_clean[:tool_call_id] = tool_call_id if tool_call_id
        run.steps.create!(step_data_clean)
      else
        # Create other step types normally
        run.steps.create!(step_data.except(:tool_use_id))
      end
    end
  end
end
