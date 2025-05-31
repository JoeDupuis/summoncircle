class AddWorkplacePathToAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :agents, :workplace_path, :string
  end
end
