class AddMcpSseEndpointToAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :agents, :mcp_sse_endpoint, :string
  end
end
