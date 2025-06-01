class Step < ApplicationRecord
  belongs_to :run

  validates :raw_response, presence: true

  def parsed_response
    JSON.parse(raw_response)
  rescue JSON::ParserError
    raw_response
  end

  def content=(value)
    super(filter_sensitive_info(value))
  end

  def raw_response=(value)
    super(filter_sensitive_info(value))
  end

  private

  def filter_sensitive_info(message)
    return message unless message.present?

    # Use Rails ParameterFilter with compact to handle nil tokens gracefully
    token = run&.task&.user&.github_token
    filter = ActiveSupport::ParameterFilter.new([ token ].compact)

    # ParameterFilter works by filtering hash values, so we wrap the message
    filtered_hash = filter.filter(message: message)
    filtered_hash[:message]
  end
end
