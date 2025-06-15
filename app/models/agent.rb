class Agent < ApplicationRecord
  include Discard::Model

  has_many :tasks, dependent: :destroy
  has_many :volumes, dependent: :destroy
  has_many :agent_specific_settings, dependent: :destroy

  accepts_nested_attributes_for :agent_specific_settings, allow_destroy: true

  validates :name, presence: true
  validates :docker_image, presence: true
  validates :workplace_path, presence: true
  validates :user_id, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  attr_accessor :volumes_config, :env_variables_json

  def volumes_config
    return @volumes_config if @volumes_config.present?
    return "" if volumes.empty?

    volumes.map do |volume|
      if volume.external?
        [ volume.name, {
          "path" => volume.path,
          "external" => true,
          "external_name" => volume.external_name
        } ]
      else
        [ volume.name, volume.path ]
      end
    end.to_h.to_json
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

  def update_setting_types(selected_types)
    selected_types ||= []
    current_types = agent_specific_settings.pluck(:type)

    # Add new settings
    (selected_types - current_types).each do |type|
      agent_specific_settings.create!(type: type)
    end

    # Remove deselected settings
    (current_types - selected_types).each do |type|
      agent_specific_settings.where(type: type).destroy_all
    end
  end
end
