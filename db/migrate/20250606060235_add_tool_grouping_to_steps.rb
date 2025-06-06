class AddToolGroupingToSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :steps, :tool_call_id, :integer
    add_column :steps, :tool_use_id, :string

    add_index :steps, :tool_call_id
    add_index :steps, [ :run_id, :tool_use_id ], name: "index_steps_on_run_id_and_tool_use_id"
  end
end
