class AddAutoTaskNamingAgentToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :auto_task_naming_agent_id, :integer
    add_index :users, :auto_task_naming_agent_id
    add_foreign_key :users, :agents, column: :auto_task_naming_agent_id
  end
end
