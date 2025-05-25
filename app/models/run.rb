class Run < ApplicationRecord
  belongs_to :task

  validates :status, inclusion: { in: %w[pending running completed failed] }
end
