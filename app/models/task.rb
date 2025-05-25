class Task < ApplicationRecord
  belongs_to :project
  belongs_to :agent
  has_many :runs, dependent: :destroy

  def run(prompt)
    run = runs.create!(prompt: prompt)
    RunJob.perform_later(run.id)
    run
  end
end
