class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :name
      t.text :description
      t.string :repository_url
      t.text :setup_script

      t.timestamps
    end
  end
end
