class AgentSpecificSetting < ApplicationRecord
  belongs_to :agent

  validates :type, presence: true

  # Override in subclasses to provide setting-specific views
  def render_partial
    "agent_specific_settings/#{self.class.name.underscore}"
  end

  # Get all available agent-specific setting types
  def self.available_types
    # Get all subclasses of AgentSpecificSetting
    subclasses = Dir[Rails.root.join("app/models/*_setting.rb")].map do |file|
      basename = File.basename(file, ".rb")
      klass_name = basename.camelize
      klass_name.constantize if klass_name.constantize < AgentSpecificSetting
    end.compact

    # Return hash with type and display name
    subclasses.map do |klass|
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
