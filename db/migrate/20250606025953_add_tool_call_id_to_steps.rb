class AddToolCallIdToSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :steps, :tool_call_id, :integer
    add_index :steps, :tool_call_id
    add_foreign_key :steps, :steps, column: :tool_call_id
  end
end
