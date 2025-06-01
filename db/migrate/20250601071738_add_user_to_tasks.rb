class AddUserToTasks < ActiveRecord::Migration[8.0]
  def change
    add_reference :tasks, :user, null: false, foreign_key: true
  end
end
