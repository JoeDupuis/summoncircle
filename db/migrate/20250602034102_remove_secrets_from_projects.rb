class RemoveSecretsFromProjects < ActiveRecord::Migration[8.0]
  def change
    remove_column :projects, :secrets, :text
  end
end
