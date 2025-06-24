class AddParentToolUseIdToSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :steps, :parent_tool_use_id, :string
  end
end
