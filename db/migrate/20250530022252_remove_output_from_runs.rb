class RemoveOutputFromRuns < ActiveRecord::Migration[8.0]
  def change
    remove_column :runs, :output, :text
  end
end
