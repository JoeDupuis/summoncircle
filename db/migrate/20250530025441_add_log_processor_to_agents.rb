class AddLogProcessorToAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :agents, :log_processor, :string, default: "Text"
  end
end
