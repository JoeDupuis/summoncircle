class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :tasks, dependent: :destroy

  encrypts :github_token, deterministic: false
  encrypts :ssh_key, deterministic: false

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  enum :role, { standard: 0, admin: 1 }, allow_nil: true
end
