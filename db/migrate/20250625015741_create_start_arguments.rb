class CreateStartArguments < ActiveRecord::Migration[8.0]
  def change
    create_table :start_arguments do |t|
      t.references :agent, null: false, foreign_key: true
      t.text :value, null: false
      t.integer :position

      t.timestamps
    end

    add_index :start_arguments, [ :agent_id, :position ]
  end
end
