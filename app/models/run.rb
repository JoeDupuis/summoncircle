class Run < ApplicationRecord
  belongs_to :task

  enum :status, { pending: 0, running: 1, completed: 2, failed: 3 }, default: :pending
end
