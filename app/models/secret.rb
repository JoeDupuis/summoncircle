class Secret < ApplicationRecord
  belongs_to :secretable, polymorphic: true

  encrypts :value, deterministic: false

  validates :key, presence: true, uniqueness: { scope: [ :secretable_type, :secretable_id ] }
  validates :value, presence: true, on: :create

  before_validation :skip_blank_value_on_update

  private

  def skip_blank_value_on_update
    if persisted? && value.blank?
      self.value = value_was
    end
  end
end
