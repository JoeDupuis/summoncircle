class Run < ApplicationRecord
  belongs_to :task
  has_many :siblings, through: :task, source: :runs

  enum :status, { pending: 0, running: 1, completed: 2, failed: 3 }, default: :pending

  def first_run?
    siblings.where.not(id: id).none?
  end
end
