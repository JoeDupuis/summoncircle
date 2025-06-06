class PopulateToolCallIds < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE steps
      SET tool_call_id = (
        SELECT id#{' '}
        FROM steps AS tool_calls#{' '}
        WHERE tool_calls.type = 'Step::ToolCall'#{' '}
        AND tool_calls.tool_use_id = steps.tool_use_id
        AND tool_calls.run_id = steps.run_id
      )
      WHERE steps.type = 'Step::ToolResult'#{' '}
      AND steps.tool_use_id IS NOT NULL
    SQL
  end

  def down
    execute "UPDATE steps SET tool_call_id = NULL WHERE type = 'Step::ToolResult'"
  end
end
