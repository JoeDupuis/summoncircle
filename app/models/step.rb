class Step < ApplicationRecord
  belongs_to :run

  validates :raw_response, presence: true

  def parsed_response
    JSON.parse(raw_response)
  rescue JSON::ParserError
    raw_response
  end

  def content
    filter_sensitive_info(super)
  end

  def raw_response
    filter_sensitive_info(super)
  end

  private

  def filter_sensitive_info(message)
    return message unless message.present?

    token = run&.task&.user&.github_token
    return message unless token.present?

    message.gsub(token, "[FILTERED]")
  end
end
