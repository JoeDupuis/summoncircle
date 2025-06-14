class AddNamedVolumeMountsToAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :agents, :named_volume_mounts, :json, default: {}
  end
end
