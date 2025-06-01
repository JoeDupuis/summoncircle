class AddDiscardedAtToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :discarded_at, :datetime
    add_index :tasks, :discarded_at
  end
end
