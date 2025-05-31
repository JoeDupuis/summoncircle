class AddIndexToStepsType < ActiveRecord::Migration[8.0]
  def change
    add_index :steps, :type
  end
end
