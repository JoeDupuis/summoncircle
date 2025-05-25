class Task < ApplicationRecord
  belongs_to :project
  belongs_to :agent
  has_many :runs, dependent: :destroy

  def run(prompt)
    is_initial = runs.count == 0
    run = runs.create!(
      prompt: prompt,
      is_initial: is_initial,
      started_at: Time.current
    )
    agent.execute(run)
    run
  end
end
