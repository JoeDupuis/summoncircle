require "shellwords"

class GitPushTool < ApplicationTool
  description "Push a git branch to a remote repository using GitHub authentication"

  arguments do
    required(:repo_path).filled(:string).description("Path to the git repository")
    required(:branch).filled(:string).description("Branch name to push")
    optional(:remote).filled(:string).description("Remote name to push to (defaults to 'origin')")
    required(:user_id).filled(:integer).description("User ID to fetch GitHub token from")
  end

  def call(repo_path:, branch:, user_id:, remote: "origin")
    user = User.find_by(id: user_id)
    unless user
      return { success: false, error: "User not found with ID: #{user_id}" }
    end

    unless user.github_token.present?
      return { success: false, error: "User does not have a GitHub token configured" }
    end

    github_token = user.github_token
    repo_path = File.expand_path(repo_path)

    unless Dir.exist?(repo_path)
      return { success: false, error: "Repository path does not exist: #{repo_path}" }
    end

    unless Dir.exist?(File.join(repo_path, ".git"))
      return { success: false, error: "Not a git repository: #{repo_path}" }
    end

    Dir.chdir(repo_path) do
      # Get the remote URL
      remote_url = `git remote get-url #{Shellwords.escape(remote)} 2>&1`.strip

      if $?.exitstatus != 0
        return { success: false, error: "Failed to get remote URL: #{remote_url}" }
      end

      # Modify the URL to include the token
      authenticated_url = add_token_to_url(remote_url, github_token)

      # Temporarily set the remote URL with authentication
      original_url = remote_url
      `git remote set-url #{Shellwords.escape(remote)} #{Shellwords.escape(authenticated_url)} 2>&1`

      begin
        # Push the branch
        output = `git push #{Shellwords.escape(remote)} #{Shellwords.escape(branch)} 2>&1`
        success = $?.exitstatus == 0

        {
          success: success,
          output: output,
          branch: branch,
          remote: remote,
          repository: repo_path
        }
      ensure
        # Always restore the original URL
        `git remote set-url #{Shellwords.escape(remote)} #{Shellwords.escape(original_url)} 2>&1`
      end
    end
  rescue => e
    { success: false, error: "Exception occurred: #{e.message}" }
  end

  private

  def add_token_to_url(url, token)
    case url
    when /^git@github\.com:(.+)$/
      # Convert SSH URL to HTTPS with token
      "https://#{token}@github.com/#{$1}"
    when /^https:\/\/github\.com\/(.+)$/
      # Add token to HTTPS URL
      "https://#{token}@github.com/#{$1}"
    when /^https:\/\/(.+)@github\.com\/(.+)$/
      # Replace existing token in HTTPS URL
      "https://#{token}@github.com/#{$2}"
    else
      # Return original URL if not a GitHub URL
      url
    end
  end
end
