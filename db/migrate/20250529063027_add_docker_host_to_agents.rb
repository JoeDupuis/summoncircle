class AddDockerHostToAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :agents, :docker_host, :string
  end
end
