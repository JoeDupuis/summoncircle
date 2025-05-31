class ChangeVolumeIdToNullableInVolumeMounts < ActiveRecord::Migration[8.0]
  def change
    change_column_null :volume_mounts, :volume_id, true
  end
end
