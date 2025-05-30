class Step < ApplicationRecord
  belongs_to :run

  validates :raw_response, presence: true
end
