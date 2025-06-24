class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  encrypts :github_token, deterministic: false
  encrypts :ssh_key, deterministic: false

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  enum :role, { standard: 0, admin: 1 }, allow_nil: true

  def env_strings
    vars = []
    vars << "GITHUB_TOKEN=#{github_token}" if github_token.present? && allow_github_token_access
    vars
  end
end
