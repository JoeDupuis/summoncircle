class Project < ApplicationRecord
  include Discard::Model

  has_many :tasks, dependent: :destroy
  validates :name, presence: true
  validates :repository_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid HTTP or HTTPS URL", allow_blank: true }

  def safe_repository_url
    return nil unless repository_url.present?
    return nil unless repository_url.start_with?("http://", "https://")

    repository_url
  end

  def repository_url_with_token(user)
    return nil unless repository_url.present?
    return repository_url unless user&.github_token.present?
    return repository_url unless repository_url.include?("github.com")

    uri = URI.parse(repository_url)
    if uri.host == "github.com"
      "https://#{user.github_token}@github.com#{uri.path}"
    else
      repository_url
    end
  end
end
