class RenameDevDockerfileToPath < ActiveRecord::Migration[8.0]
  def change
    rename_column :projects, :dev_dockerfile, :dev_dockerfile_path
  end
end
