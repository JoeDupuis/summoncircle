class AddGitDiffToRepoStates < ActiveRecord::Migration[8.0]
  def change
    add_column :repo_states, :git_diff, :text
  end
end
