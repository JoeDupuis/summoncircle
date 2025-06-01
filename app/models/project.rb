class Project < ApplicationRecord
  include Discard::Model

  has_many :tasks, dependent: :destroy
  validates :name, presence: true
  validates :repository_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid HTTP or HTTPS URL" }

  def safe_repository_url
    return nil unless repository_url.present?
    return nil unless repository_url.start_with?("http://", "https://")

    repository_url
  end
end
