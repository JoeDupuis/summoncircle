class RenameEnvironmentVariablesToEnvVariablesOnAgents < ActiveRecord::Migration[8.0]
  def change
    rename_column :agents, :environment_variables, :env_variables
  end
end
