class AddGitConfigToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :git_config, :text
  end
end
