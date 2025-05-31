class Agent < ApplicationRecord
  has_many :tasks, dependent: :destroy
  has_many :volumes, dependent: :destroy

  validates :name, presence: true
  validates :docker_image, presence: true

  attr_accessor :volumes_config, :environment_variables_config

  def volumes_config
    return @volumes_config if @volumes_config.present?
    return "" if volumes.empty?

    volumes.pluck(:name, :path).to_h.to_json
  end

  def environment_variables_config
    return @environment_variables_config if @environment_variables_config.present?
    return "" if environment_variables.blank?

    environment_variables.to_json
  end

  def environment_variables_config=(value)
    @environment_variables_config = value
    return if value.blank?

    begin
      parsed = JSON.parse(value)
      write_attribute(:environment_variables, parsed)
    rescue JSON::ParserError
      errors.add(:environment_variables_config, "must be valid JSON")
    end
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
