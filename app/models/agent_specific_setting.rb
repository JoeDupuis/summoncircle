class AgentSpecificSetting < ApplicationRecord
  belongs_to :agent

  validates :type, presence: true

  # Get all available agent-specific setting types
  def self.available_types
    # Ensure all setting classes are loaded
    Rails.application.eager_load! if Rails.env.development?
    
    descendants.map do |klass|
      {
        type: klass.name,
        display_name: klass.display_name,
        description: klass.description
      }
    end
  end

  # Override in subclasses to provide a display name
  def self.display_name
    name.demodulize.underscore.humanize
  end

  # Override in subclasses to provide a description
  def self.description
    "Enable #{display_name}"
  end
end
