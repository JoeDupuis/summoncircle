class Project < ApplicationRecord
  validates :name, presence: true
  validates :repository_url, presence: true
end
