class AddSshMountPathToAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :agents, :ssh_mount_path, :string
  end
end
