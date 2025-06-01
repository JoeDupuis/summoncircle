class AddUserInstructionsFeature < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :instructions, :text
    add_column :agents, :instructions_mount_path, :string
  end
end
