class Task < ApplicationRecord
  belongs_to :project
  belongs_to :agent
  has_many :runs, dependent: :destroy
  has_many :volume_mounts, dependent: :destroy

  def run(prompt)
    run = runs.create!(prompt: prompt)
    create_volume_mounts
    RunJob.perform_later(run.id)
    run
  end

  private

  def create_volume_mounts
    agent.volumes.each do |volume|
      volume_mounts.find_or_create_by!(volume: volume)
    end
  end
end
