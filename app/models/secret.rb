class Secret < ApplicationRecord
  belongs_to :project

  encrypts :value, deterministic: false

  validates :key, presence: true, uniqueness: { scope: :project_id }
  validates :value, presence: true
end
