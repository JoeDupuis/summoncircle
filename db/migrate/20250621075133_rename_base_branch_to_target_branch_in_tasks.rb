class RenameBaseBranchToTargetBranchInTasks < ActiveRecord::Migration[8.0]
  def change
    rename_column :tasks, :base_branch, :target_branch
  end
end
