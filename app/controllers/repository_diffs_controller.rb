class RepositoryDiffsController < ApplicationController
  before_action :set_task

  def show
    # Try to get the latest repo state with git_apply_diff
    repo_state = @task.runs
                      .joins(steps: :repo_states)
                      .where.not(repo_states: { git_apply_diff: nil })
                      .order("runs.created_at DESC, steps.created_at DESC")
                      .limit(1)
                      .pluck("repo_states.git_apply_diff")
                      .first

    if repo_state.blank?
      # Fallback to any repo state with diffs
      latest_state = RepoState
                      .joins(step: :run)
                      .where(step: { run: { task_id: @task.id } })
                      .where("repo_states.uncommitted_diff IS NOT NULL OR repo_states.target_branch_diff IS NOT NULL")
                      .order("runs.created_at DESC, steps.created_at DESC")
                      .first

      if latest_state
        diff = latest_state.target_branch_diff.presence || latest_state.uncommitted_diff
        render json: { diff: diff || "" }
      else
        render json: { diff: "" }
      end
    else
      render json: { diff: repo_state }
    end
  end

  private

  def set_task
    @task = Task.find(params[:task_id])
    unless @task.user == Current.user
      head :forbidden
    end
  end
end
