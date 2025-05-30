class CreateSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :steps do |t|
      t.references :run, null: false, foreign_key: true
      t.json :raw_response

      t.timestamps
    end
  end
end
