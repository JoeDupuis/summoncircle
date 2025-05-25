class ChangeStatusToIntegerInRuns < ActiveRecord::Migration[8.0]
  def change
    # Remove the old string column
    remove_column :runs, :status, :string

    # Add the new integer column with default
    add_column :runs, :status, :integer, default: 0, null: false
  end
end
