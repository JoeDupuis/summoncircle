class RunJob < ApplicationJob
  queue_as :default

  def perform(run_id)
    Run.find(run_id).execute!
  end
end
