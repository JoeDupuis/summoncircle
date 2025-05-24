class CreateAgents < ActiveRecord::Migration[8.0]
  def change
    create_table :agents do |t|
      t.string :name
      t.string :docker_image
      t.text :agent_prompt
      t.text :setup_script
      t.json :start_arguments
      t.json :continue_arguments

      t.timestamps
    end
  end
end
