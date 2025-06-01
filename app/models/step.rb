class Step < ApplicationRecord
  belongs_to :run
  has_many :repo_states, dependent: :destroy

  validates :raw_response, presence: true

  def parsed_response
    JSON.parse(raw_response)
  rescue JSON::ParserError
    raw_response
  end
end
