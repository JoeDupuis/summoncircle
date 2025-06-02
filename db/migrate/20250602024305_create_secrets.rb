class CreateSecrets < ActiveRecord::Migration[8.0]
  def change
    create_table :secrets do |t|
      t.references :project, null: false, foreign_key: true
      t.string :key, null: false
      t.text :value

      t.timestamps
    end

    add_index :secrets, [ :project_id, :key ], unique: true
  end
end
