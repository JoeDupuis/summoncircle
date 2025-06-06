class Step < ApplicationRecord
  belongs_to :run
  has_many :repo_states, dependent: :destroy
  belongs_to :tool_call, class_name: "Step::ToolCall", optional: true
  has_one :tool_result, class_name: "Step::ToolResult", foreign_key: :tool_call_id

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

    filtered_message = message.dup

    github_token = run&.task&.user&.github_token
    if github_token.present?
      filtered_message = filtered_message.gsub(github_token, "[FILTERED]")
    end

    ssh_key = run&.task&.user&.ssh_key
    if ssh_key.present?
      ssh_key_lines = ssh_key.lines.map(&:strip).reject(&:empty?)
      ssh_key_lines.each do |line|
        filtered_message = filtered_message.gsub(line, "[FILTERED]")
      end
    end

    project_secret_values = run&.task&.project&.secret_values || []
    project_secret_values.each do |secret_value|
      next unless secret_value.present?

      filtered_message = filtered_message.gsub(secret_value, "[FILTERED]")
    end

    filtered_message
  end
end
