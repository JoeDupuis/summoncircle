class RemoveUnusedColumnsFromAgents < ActiveRecord::Migration[8.0]
  def change
    remove_column :agents, :claude_config_volume_name, :string
    remove_column :agents, :named_volume_mounts, :json
  end
end
