class AddHomePathToAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :agents, :home_path, :string
  end
end
