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
    return message unless run&.task&.user&.github_token.present?

    # Simple string replacement to filter out the token
    message.gsub(run.task.user.github_token, "[FILTERED]")
  end
end
