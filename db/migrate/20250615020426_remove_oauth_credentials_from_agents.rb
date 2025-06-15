class RemoveOauthCredentialsFromAgents < ActiveRecord::Migration[8.0]
  def change
    remove_column :agents, :oauth_credentials, :text
  end
end
