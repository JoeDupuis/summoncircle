class CreateEnvVariables < ActiveRecord::Migration[8.0]
  def change
    create_table :env_variables do |t|
      t.string :key, null: false
      t.string :value
      t.references :envable, polymorphic: true, null: false

      t.timestamps
    end

    add_index :env_variables, [ :envable_type, :envable_id, :key ], unique: true, name: 'index_env_vars_on_envable_and_key'
  end
end
