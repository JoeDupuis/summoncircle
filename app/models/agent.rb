class Agent < ApplicationRecord
  has_many :tasks, dependent: :destroy

  validates :name, presence: true
  validates :docker_image, presence: true
end
