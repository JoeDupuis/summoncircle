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

  def workplace_mount
    return nil unless agent.workplace_path.present?

    {
      volume_name: "summoncircle_workplace_volume_#{SecureRandom.uuid}",
      container_path: agent.workplace_path
    }
  end

  private

  def create_volume_mounts
    agent.volumes.each do |volume|
      volume_mounts.find_or_create_by!(volume: volume)
    end
  end
end
