class Agent < ApplicationRecord
  has_many :tasks, dependent: :destroy
  has_many :volumes, dependent: :destroy

  validates :name, presence: true
  validates :docker_image, presence: true
  validates :log_processor, inclusion: { in: %w[LogProcessor LogProcessor::ClaudeStreamingJson] }

  attr_accessor :volumes_config

  def volumes_config
    return @volumes_config if @volumes_config.present?
    return "" if volumes.empty?

    volumes.pluck(:name, :path).to_h.to_json
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
    log_processor.constantize
  end
end
