class AddDescriptionToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :description, :text
  end
end