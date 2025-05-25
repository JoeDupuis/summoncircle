class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.references :project, null: false, foreign_key: true
      t.references :agent, null: false, foreign_key: true
      t.string :status
      t.datetime :started_at
      t.datetime :archived_at

      t.timestamps
    end
  end
end
