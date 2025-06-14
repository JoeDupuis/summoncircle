class AddExternalToVolumes < ActiveRecord::Migration[8.0]
  def change
    add_column :volumes, :external, :boolean, default: false
    add_column :volumes, :external_name, :string
  end
end
