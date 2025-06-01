class ChangeUserIdToNonNullableOnAgents < ActiveRecord::Migration[8.0]
  def change
    change_column_null :agents, :user_id, false, 1000
  end
end
