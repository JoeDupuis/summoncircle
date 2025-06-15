class CreateAgentSpecificSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_specific_settings do |t|
      t.references :agent, null: false, foreign_key: true
      t.string :type, null: false

      t.timestamps
    end

    add_index :agent_specific_settings, [ :agent_id, :type ], unique: true
  end
end
