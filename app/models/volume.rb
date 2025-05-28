class Volume < ApplicationRecord
  belongs_to :agent
  has_many :volume_mounts, dependent: :destroy

  validates :name, presence: true
  validates :path, presence: true
end
