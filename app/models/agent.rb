class Agent < ApplicationRecord
  has_many :tasks, dependent: :destroy

  validates :name, presence: true
  validates :docker_image, presence: true
  validates :agent_prompt, presence: true
  validates :setup_script, presence: true

  def start_arguments=(value)
    parsed = value.is_a?(String) && value.present? ? JSON.parse(value) : value
    super(parsed)
  end

  def continue_arguments=(value)
    parsed = value.is_a?(String) && value.present? ? JSON.parse(value) : value
    super(parsed)
  end
end
