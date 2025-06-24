class AddContainerIdToRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :runs, :container_id, :string
  end
end
