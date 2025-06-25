class StartArgument < ApplicationRecord
  belongs_to :agent

  validates :value, presence: true
end
