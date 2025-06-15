class ClaudeOauthSetting < AgentSpecificSetting
  def oauth
    @oauth ||= ClaudeOauth.new(agent)
  end

  def credentials_exist?
    oauth.check_credentials_exist
  rescue => e
    Rails.logger.error "Failed to check OAuth credentials: #{e.message}"
    false
  end

  def token_expiry
    oauth.get_token_expiry
  rescue => e
    Rails.logger.error "Failed to get token expiry: #{e.message}"
    nil
  end

  def self.display_name
    "Claude OAuth"
  end

  def self.description
    "Enable OAuth authentication for Claude CLI access"
  end
end
