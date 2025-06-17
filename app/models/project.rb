class Project < ApplicationRecord
  include Discard::Model

  has_many :tasks, dependent: :destroy
  has_many :secrets, dependent: :destroy
  validates :name, presence: true
  validates :repository_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid HTTP or HTTPS URL", allow_blank: true }

  def safe_repository_url
    return nil unless repository_url.present?
    return nil unless repository_url.start_with?("http://", "https://")

    repository_url
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
end
