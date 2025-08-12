class AddGitlabTokenToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :gitlab_token, :text
    add_column :users, :allow_gitlab_token_access, :boolean, default: true, null: false
  end
end
