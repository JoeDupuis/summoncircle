class Secret < ApplicationRecord
  belongs_to :secretable, polymorphic: true

  encrypts :value, deterministic: false

  validates :key, presence: true, uniqueness: { scope: [ :secretable_type, :secretable_id ] }
  validates :value, presence: true
end
