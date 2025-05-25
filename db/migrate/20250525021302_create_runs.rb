class CreateRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :runs do |t|
      t.references :task, null: false, foreign_key: true
      t.text :prompt
      t.text :output
      t.integer :status, default: 0, null: false
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end
