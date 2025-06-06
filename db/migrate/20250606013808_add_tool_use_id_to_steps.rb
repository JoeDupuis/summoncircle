class AddToolUseIdToSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :steps, :tool_use_id, :string
    add_index :steps, [ :tool_use_id, :id ], name: "index_steps_on_tool_use_id_and_id"
  end
end
