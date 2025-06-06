class AddIndexesToStepsForToolLinking < ActiveRecord::Migration[8.0]
  def change
    # Composite index for finding tool calls by type and run efficiently
    add_index :steps, [ :run_id, :type ], name: "index_steps_on_run_id_and_type"

    # Index for tool_call_id lookups (already exists but ensuring it's optimal)
    # add_index :steps, :tool_call_id (already exists)
  end
end
