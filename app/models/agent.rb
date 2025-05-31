class Agent < ApplicationRecord
  has_many :tasks, dependent: :destroy
  has_many :volumes, dependent: :destroy

  validates :name, presence: true
  validates :docker_image, presence: true
  validates :workplace_path, presence: true

  attr_accessor :volumes_config, :env_variables_json

  def volumes_config
    return @volumes_config if @volumes_config.present?
    return "" if volumes.empty?

    volumes.pluck(:name, :path).to_h.to_json
  end

  def env_variables_json
    return @env_variables_json if @env_variables_json.present?
    return "" if env_variables.blank?

    env_variables.to_json
  end

  def env_variables_json=(value)
    @env_variables_json = value
    return if value.blank?

    begin
      parsed = JSON.parse(value)
      self.env_variables = parsed
    rescue JSON::ParserError
      errors.add(:env_variables_json, "must be valid JSON")
    end
  end

  def env_strings
    return [] if env_variables.blank?

    env_variables.map { |key, value| "#{key}=#{value}" }
  end

  def start_arguments=(value)
    parsed = value.is_a?(String) && value.present? ? JSON.parse(value) : value
    super(parsed)
  end

  def continue_arguments=(value)
    parsed = value.is_a?(String) && value.present? ? JSON.parse(value) : value
    super(parsed)
  end


  def log_processor_class
    "LogProcessor::#{log_processor}".constantize
  end
end
