class AddOauthCredentialsToAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :agents, :oauth_credentials, :text
  end
end
