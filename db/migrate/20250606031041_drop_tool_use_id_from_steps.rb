class DropToolUseIdFromSteps < ActiveRecord::Migration[8.0]
  def change
    remove_column :steps, :tool_use_id, :string
  end
end
