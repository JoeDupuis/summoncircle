class AddVolumeNameToVolumeMounts < ActiveRecord::Migration[8.0]
  def change
    add_column :volume_mounts, :volume_name, :string
  end
end
