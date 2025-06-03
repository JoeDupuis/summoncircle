class AddSshKeyToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :ssh_key, :text
  end
end
