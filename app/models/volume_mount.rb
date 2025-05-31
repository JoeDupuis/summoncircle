class VolumeMount < ApplicationRecord
  belongs_to :volume, optional: true
  belongs_to :task

  validates :volume_id, uniqueness: { scope: :task_id }, allow_nil: true
  
  before_validation :generate_volume_name
  
  def container_path
    volume&.path || task.agent.workplace_path
  end
  
  def bind_string
    "#{volume_name}:#{container_path}"
  end
  
  private
  
  def generate_volume_name
    return if volume_name.present?
    
    base_name = volume&.name || "workplace"
    self.volume_name = "summoncircle_#{base_name}_volume_#{SecureRandom.uuid}"
  end
end
