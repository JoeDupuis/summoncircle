class AddEnvironmentVariablesToAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :agents, :environment_variables, :json
  end
end
