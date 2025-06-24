class Agent < ApplicationRecord
  include Discard::Model

  has_many :tasks, dependent: :destroy
  has_many :volumes, dependent: :destroy
  has_many :agent_specific_settings, dependent: :destroy
  has_many :secrets, as: :secretable, dependent: :destroy

  accepts_nested_attributes_for :agent_specific_settings, allow_destroy: true, reject_if: :reject_new_destroyed_settings

  validates :name, presence: true
  validates :docker_image, presence: true
  validates :workplace_path, presence: true
  validates :user_id, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_save :update_agent_specific_setting

  attr_accessor :volumes_config, :env_variables_json, :agent_specific_setting_type

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
    vars = []
    vars += env_variables.map { |key, value| "#{key}=#{value}" } if env_variables.present?
    vars += secrets.map { |secret| "#{secret.key}=#{secret.value}" }
    vars
  end

  def update_secrets(secrets_hash)
    return unless secrets_hash.is_a?(Hash)

    secrets_hash.each do |key, value|
      next if key.blank? || value.blank?

      secret = secrets.find_or_initialize_by(key: key)
      secret.value = value
      secret.save!
    end
  end

  def secrets_hash
    secrets.pluck(:key, :value).to_h
  end

  def secret_values
    secrets.pluck(:value)
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

  private

  def reject_new_destroyed_settings(attributes)
    attributes["id"].blank? && [ "1", "true", true ].include?(attributes["_destroy"])
  end

  def update_agent_specific_setting
    return unless agent_specific_setting_type_changed?

    # Remove existing setting if selecting "None"
    if agent_specific_setting_type.blank?
      agent_specific_settings.destroy_all
      return
    end

    # Remove existing setting if different type
    current_setting = agent_specific_settings.first
    if current_setting && current_setting.type != agent_specific_setting_type
      current_setting.destroy
    end

    # Create new setting if none exists
    if agent_specific_settings.empty? || agent_specific_settings.all?(&:marked_for_destruction?)
      agent_specific_settings.build(type: agent_specific_setting_type)
    end
  end

  def agent_specific_setting_type_changed?
    @agent_specific_setting_type != agent_specific_settings.first&.type
  end
end
