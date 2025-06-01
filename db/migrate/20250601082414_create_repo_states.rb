class CreateRepoStates < ActiveRecord::Migration[8.0]
  def change
    create_table :repo_states do |t|
      t.text :uncommitted_diff
      t.text :target_branch_diff
      t.string :repository_path
      t.references :step, null: false, foreign_key: true

      t.timestamps
    end
  end
end
