module GitOperations
  extend ActiveSupport::Concern

  def clone_repository(task = nil)
    task ||= self.is_a?(Task) ? self : self.task
    project = task.project
    repo_path = project.repo_path.presence || ""
    clone_target = repo_path.presence&.sub(/^\//, "") || "."
    repository_url = project.repository_url

    validate_ssh_setup!(task, repository_url)

    if task.target_branch.present?
      command = "git clone -b '#{task.target_branch}' '#{repository_url}' '#{clone_target}'"
    else
      # Clone without specifying branch, then detect and save the default branch
      command = "git clone '#{repository_url}' '#{clone_target}'"
    end

    run_git_command(
      task: task,
      command: command,
      working_dir: task.workplace_mount.container_path,
      error_message: "Failed to clone repository",
      skip_repo_path: true  # Clone operates from workspace root
    )

    # If target_branch was nil, detect and save the default branch
    if task.target_branch.blank?
      detect_and_save_default_branch(task)
    end
  end

  def detect_and_save_default_branch(task)
    begin
      # Get the current branch name (which will be the default after clone)
      logs = run_git_command(
        task: task,
        command: "git branch --show-current",
        error_message: "Failed to detect current branch",
        return_logs: true
      )

      default_branch = logs.strip
      if default_branch.present?
        task.update_column(:target_branch, default_branch)
      end
    rescue => e
      Rails.logger.error "Failed to detect default branch: #{e.message}"
    end
  end

  def push_changes_to_branch(commit_message = nil)
    task = self.is_a?(Task) ? self : self.task
    return unless task.auto_push_enabled? && task.auto_push_branch.present?
    return unless task.project.repository_url.present?

    repository_url = task.project.repository_url
    commit_message ||= "Manual push from SummonCircle"

    validate_ssh_setup!(task, repository_url)

    push_commands = [
      "git remote set-url origin '#{repository_url}'",
      "git add -A",
      "git diff --cached --quiet || git commit -m '#{commit_message}'",
      "git push origin HEAD:#{task.auto_push_branch}"
    ].join(" && ")

    run_git_command(
      task: task,
      command: push_commands,
      error_message: "Failed to push changes"
    )
  end



  def fetch_branches(task = nil)
    task ||= self.is_a?(Task) ? self : self.task
    return [] unless task.project.repository_url.present?

    begin
      logs = run_git_command(
        task: task,
        command: "git branch",
        error_message: "Failed to fetch branches",
        return_logs: true
      )

      branches = logs.lines.map do |line|
        # Remove the * for current branch and any whitespace
        line.strip.sub(/^\*\s*/, "")
      end.reject(&:blank?).reject do |branch|
        # Filter out detached HEAD branches
        branch.match(/^\(HEAD detached at [a-fA-F0-9]+\)$/)
      end

      branches.presence || []
    rescue => e
      Rails.logger.error "Failed to fetch branches: #{e.message}"
      []
    end
  end

  def capture_repository_state(run = nil)
    run ||= self if self.is_a?(Run)
    task = run.task
    project = task.project
    return nil unless project.repository_url.present?

    begin
      command = "git add -N . && git diff HEAD --unified=10"

      diff_output = run_git_command(
        task: task,
        command: command,
        error_message: "Failed to capture git diff",
        return_logs: true
      )

      target_branch_diff = nil
      if task.target_branch.present?
        begin
          target_branch_diff = run_git_command(
            task: task,
            command: "git diff origin/#{task.target_branch}...HEAD --unified=10",
            error_message: "Failed to capture target branch diff",
            return_logs: true
          )
        rescue => e
          Rails.logger.error "Failed to capture target branch diff: #{e.message}"
        end
      end

      # Return early only if both diffs are empty
      return nil if diff_output.blank? && target_branch_diff.blank?

      repo_path = project.repo_path.presence || ""
      working_dir = task.workplace_mount.container_path
      git_working_dir = File.join([ working_dir, repo_path.presence&.sub(/^\//, "") ].compact)

      repo_state_step = run.steps.create!(
        raw_response: "Repository state captured",
        type: "Step::System",
        content: "Repository state captured"
      )

      # Capture git diff (all changes including untracked files)
      git_diff = nil
      begin
        if task.target_branch.present?
          git_diff_command = "git add -N . && git diff origin/#{task.target_branch}...HEAD --unified=10"
        else
          git_diff_command = "git add -N . && git diff HEAD --unified=10"
        end

        git_diff = run_git_command(
          task: task,
          command: git_diff_command,
          error_message: "Failed to capture git diff",
          return_logs: true
        )
      rescue => e
        Rails.logger.error "Failed to capture git diff: #{e.message}"
      end

      repo_state_step.repo_states.create!(
        uncommitted_diff: diff_output,
        target_branch_diff: target_branch_diff,
        repository_path: git_working_dir,
        git_diff: git_diff
      )
    rescue => e
      Rails.logger.error "Failed to capture repository state: #{e.message}"
      nil
    end
  end

  private

  def run_git_command(task:, command:, error_message:, return_logs: false, working_dir: nil, skip_repo_path: false)
    DockerGitCommand.new(
      task: task,
      command: command,
      error_message: error_message,
      return_logs: return_logs,
      working_dir: working_dir,
      skip_repo_path: skip_repo_path
    ).execute
  end


  def validate_ssh_setup!(task, repository_url)
    return unless repository_url&.match?(/\Agit@|ssh:\/\//)

    user = task.user
    agent = task.agent

    if user.ssh_key.blank?
      raise "SSH authentication required: The repository uses SSH authentication but no SSH key is configured. Please add an SSH key in your user settings."
    end

    if agent.ssh_mount_path.blank?
      raise "SSH configuration incomplete: The agent does not have an SSH mount path configured. Please configure the agent's SSH mount path."
    end
  end
end
