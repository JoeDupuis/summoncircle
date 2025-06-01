class AddDiscardedAtToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :discarded_at, :datetime
    add_index :projects, :discarded_at
  end
end
