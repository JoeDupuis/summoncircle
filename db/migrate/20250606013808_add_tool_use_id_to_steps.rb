class AddToolUseIdToSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :steps, :tool_use_id, :string
  end
end
