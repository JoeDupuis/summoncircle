class VolumeMount < ApplicationRecord
  belongs_to :volume
  belongs_to :task

  validates :volume_id, uniqueness: { scope: :task_id }
end
