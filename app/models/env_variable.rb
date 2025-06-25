class EnvVariable < ApplicationRecord
  belongs_to :envable, polymorphic: true

  validates :key, presence: true, uniqueness: { scope: [ :envable_type, :envable_id ] }
end
