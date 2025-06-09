class AddAutoPushBranchToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :auto_push_branch, :string
    add_column :tasks, :auto_push_enabled, :boolean, default: false
  end
end
