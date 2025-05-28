class CreateVolumeMounts < ActiveRecord::Migration[8.0]
  def change
    create_table :volume_mounts do |t|
      t.references :volume, null: false, foreign_key: true
      t.references :task, null: false, foreign_key: true

      t.timestamps
    end
  end
end
