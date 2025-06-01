class AddUserIdToAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :agents, :user_id, :integer, default: 1000
  end
end
