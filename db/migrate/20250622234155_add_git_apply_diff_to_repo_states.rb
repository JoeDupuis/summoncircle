class AddGitApplyDiffToRepoStates < ActiveRecord::Migration[8.0]
  def change
    add_column :repo_states, :git_apply_diff, :text
  end
end
