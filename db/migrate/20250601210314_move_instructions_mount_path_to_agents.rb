class MoveInstructionsMountPathToAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :agents, :instructions_mount_path, :string
    remove_column :users, :instructions_mount_path, :string
  end
end
