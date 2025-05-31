class Step < ApplicationRecord
  belongs_to :run

  validates :raw_response, presence: true

  def parsed_response
    JSON.parse(raw_response)
  end
end
