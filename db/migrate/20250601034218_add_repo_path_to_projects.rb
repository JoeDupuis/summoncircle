class AddRepoPathToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :repo_path, :string
  end
end
