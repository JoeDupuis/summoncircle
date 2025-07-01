class EnvVariable < ApplicationRecord
  include SecretValidation
  
  belongs_to :envable, polymorphic: true

  validates :key, presence: true, uniqueness: { scope: [ :envable_type, :envable_id ] }
end
