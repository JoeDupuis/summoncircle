class AddGithubTokenToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :github_token, :text
  end
end
