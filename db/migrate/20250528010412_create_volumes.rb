class CreateVolumes < ActiveRecord::Migration[8.0]
  def change
    create_table :volumes do |t|
      t.string :name
      t.string :path
      t.references :agent, null: false, foreign_key: true

      t.timestamps
    end
  end
end
