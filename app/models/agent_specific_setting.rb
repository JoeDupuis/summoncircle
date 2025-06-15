class AgentSpecificSetting < ApplicationRecord
  belongs_to :agent

  validates :type, presence: true

  # Override in subclasses to provide setting-specific views
  def render_partial
    "agent_specific_settings/#{self.class.name.underscore}"
  end
end
