class PopulateToolCallIds < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM steps"
  end

  def down
  end
end
