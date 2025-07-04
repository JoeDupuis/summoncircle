class Project < ApplicationRecord
  include Discard::Model

  has_many :tasks, dependent: :destroy
  has_many :secrets, as: :secretable, dependent: :destroy
  has_many :env_variables, as: :envable, dependent: :destroy, class_name: "EnvVariable"

  accepts_nested_attributes_for :secrets, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :env_variables, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true
  validate :valid_repository_url

  def secrets_hash
    secrets.pluck(:key, :value).to_h
  end

  def secret_values
    secrets.pluck(:value)
  end

  def env_strings
    vars = []
    vars += env_variables.map { |env_var| "#{env_var.key}=#{env_var.value}" }
    vars += secrets.map { |secret| "#{secret.key}=#{secret.value}" }
    vars
  end

  private

  def valid_repository_url
    return if repository_url.blank?
    return if valid_git_url?(repository_url)

    errors.add(:repository_url, "must be a valid HTTP, HTTPS, or SSH git URL")
  end

  def valid_git_url?(url)
    return false if url.blank?

    ssh_url_pattern = /\A(ssh:\/\/)?git@[\w\.-]+:[\w\.\/-]+\.git\z/
    http_url_pattern = /\Ahttps?:\/\/.+\z/

    url.match?(ssh_url_pattern) || url.match?(http_url_pattern)
  end
end
