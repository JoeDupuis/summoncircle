class RemovePromptAndSetupFromAgents < ActiveRecord::Migration[8.0]
  def change
    remove_column :agents, :agent_prompt, :text
    remove_column :agents, :setup_script, :text
  end
end
