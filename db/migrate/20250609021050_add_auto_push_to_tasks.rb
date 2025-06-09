class AddAutoPushToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :auto_push_enabled, :boolean, default: false, null: false
    add_column :tasks, :auto_push_branch, :string
  end
end
