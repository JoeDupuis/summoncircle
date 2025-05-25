class Agent < ApplicationRecord
  has_many :tasks, dependent: :destroy

  validates :name, presence: true
  validates :docker_image, presence: true
  validates :agent_prompt, presence: true
  validates :setup_script, presence: true
end
