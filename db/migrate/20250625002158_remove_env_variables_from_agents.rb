class RemoveEnvVariablesFromAgents < ActiveRecord::Migration[8.0]
  def change
    remove_column :agents, :env_variables, :json
  end
end
