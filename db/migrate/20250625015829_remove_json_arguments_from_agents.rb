class RemoveJsonArgumentsFromAgents < ActiveRecord::Migration[8.0]
  def change
    remove_column :agents, :start_arguments, :json
    remove_column :agents, :continue_arguments, :json
  end
end
