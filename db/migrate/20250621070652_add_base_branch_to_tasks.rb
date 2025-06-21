class AddBaseBranchToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :base_branch, :string
  end
end
