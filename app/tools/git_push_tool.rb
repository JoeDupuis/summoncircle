require "shellwords"
require "docker"

class GitPushTool < ApplicationTool
  description "Push a git branch to a remote repository using GitHub authentication"

  arguments do
    required(:task_id).filled(:integer).description("Task ID to get workspace volume from")
    required(:repo_path).filled(:string).description("Path to the git repository inside the container")
    required(:branch).filled(:string).description("Branch name to push")
    optional(:remote).filled(:string).description("Remote name to push to (defaults to 'origin')")
    required(:user_id).filled(:integer).description("User ID to fetch GitHub token from")
  end

  def call(task_id:, repo_path:, branch:, user_id:, remote: "origin")
    user = User.find_by(id: user_id)
    unless user
      return { success: false, error: "User not found with ID: #{user_id}" }
    end

    unless user.github_token.present?
      return { success: false, error: "User does not have a GitHub token configured" }
    end

    task = Task.find_by(id: task_id)
    unless task
      return { success: false, error: "Task not found with ID: #{task_id}" }
    end

    github_token = user.github_token
    
    # Build the git commands to run in the container
    commands = build_git_commands(repo_path, branch, remote, github_token)
    
    # Execute in a Docker container with the workspace mounted
    execute_in_container(task, commands, repo_path, branch, remote)
  rescue => e
    { success: false, error: "Exception occurred: #{e.message}" }
  end

  private

  def build_git_commands(repo_path, branch, remote, github_token)
    # Build a script that will:
    # 1. Check if the directory exists and is a git repo
    # 2. Get the current remote URL
    # 3. Update it with the token
    # 4. Push
    # 5. Restore the original URL
    
    script = <<~BASH
      set -e
      cd #{Shellwords.escape(repo_path)}
      
      if [ ! -d ".git" ]; then
        echo "Error: Not a git repository: #{repo_path}"
        exit 1
      fi
      
      # Get the current remote URL
      ORIGINAL_URL=$(git remote get-url #{Shellwords.escape(remote)})
      
      # Function to add token to URL
      add_token_to_url() {
        local url="$1"
        local token="$2"
        
        if [[ "$url" =~ ^git@github\\.com:(.+)$ ]]; then
          echo "https://${token}@github.com/${BASH_REMATCH[1]}"
        elif [[ "$url" =~ ^https://github\\.com/(.+)$ ]]; then
          echo "https://${token}@github.com/${BASH_REMATCH[1]}"
        elif [[ "$url" =~ ^https://(.+)@github\\.com/(.+)$ ]]; then
          echo "https://${token}@github.com/${BASH_REMATCH[2]}"
        else
          echo "$url"
        fi
      }
      
      # Set the authenticated URL
      AUTH_URL=$(add_token_to_url "$ORIGINAL_URL" #{Shellwords.escape(github_token)})
      git remote set-url #{Shellwords.escape(remote)} "$AUTH_URL"
      
      # Try to push
      git push #{Shellwords.escape(remote)} #{Shellwords.escape(branch)} 2>&1
      PUSH_STATUS=$?
      
      # Always restore the original URL
      git remote set-url #{Shellwords.escape(remote)} "$ORIGINAL_URL"
      
      exit $PUSH_STATUS
    BASH
    
    script
  end
  
  def execute_in_container(task, commands, repo_path, branch, remote)
    agent = task.agent
    
    # Get the workspace mount
    workplace_mount = task.workplace_mount
    
    # Configure Docker if needed
    if agent.docker_host.present?
      Docker.url = agent.docker_host
      Docker.options = {
        read_timeout: 600,
        write_timeout: 600,
        connect_timeout: 60
      }
    end
    
    container = Docker::Container.create(
      "Image" => agent.docker_image,
      "Entrypoint" => ["bash", "-c"],
      "Cmd" => [commands],
      "User" => agent.user_id.to_s,
      "WorkingDir" => agent.workplace_path,
      "HostConfig" => {
        "Binds" => [workplace_mount.bind_string]
      }
    )
    
    container.start
    wait_result = container.wait(300) # 5 minute timeout
    logs = container.logs(stdout: true, stderr: true)
    output = logs.gsub(/^.{8}/m, "").force_encoding("UTF-8").scrub.strip
    exit_code = wait_result["StatusCode"] if wait_result.is_a?(Hash)
    
    {
      success: exit_code == 0,
      output: output,
      branch: branch,
      remote: remote,
      repository: repo_path
    }
  rescue => e
    raise
  ensure
    container&.delete(force: true) if defined?(container)
  end
end
