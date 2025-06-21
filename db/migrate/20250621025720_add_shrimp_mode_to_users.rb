class AddShrimpModeToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :shrimp_mode, :boolean, default: true, null: false
  end
end
