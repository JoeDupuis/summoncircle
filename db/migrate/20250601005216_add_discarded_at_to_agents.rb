class AddDiscardedAtToAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :agents, :discarded_at, :datetime
    add_index :agents, :discarded_at
  end
end
