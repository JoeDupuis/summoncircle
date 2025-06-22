class RemoveDockerHostFromAgents < ActiveRecord::Migration[8.0]
  def change
    remove_column :agents, :docker_host, :string
  end
end
