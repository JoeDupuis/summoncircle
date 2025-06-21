class AddAllowGithubTokenAccessToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :allow_github_token_access, :boolean, default: true, null: false
  end
end
