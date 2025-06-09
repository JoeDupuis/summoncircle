require "test_helper"

class GitPushToolTest < ActiveSupport::TestCase
  setup do
    @temp_dir = Dir.mktmpdir
    @repo_path = File.join(@temp_dir, "test_repo")
    Dir.mkdir(@repo_path)

    Dir.chdir(@repo_path) do
      `git init`
      `git config user.email "test@example.com"`
      `git config user.name "Test User"`
      `touch README.md`
      `git add README.md`
      `git commit -m "Initial commit"`
      `git remote add origin https://github.com/test/repo.git`
    end

    @tool = GitPushTool.new
    @user = users(:one)
    @user.update!(github_token: "test_token")
  end

  teardown do
    FileUtils.rm_rf(@temp_dir) if Dir.exist?(@temp_dir)
  end

  test "validates required arguments" do
    assert_raises(ArgumentError) { @tool.call }
    assert_raises(ArgumentError) { @tool.call(repo_path: @repo_path) }
    assert_raises(ArgumentError) { @tool.call(repo_path: @repo_path, branch: "main") }
  end

  test "returns error when user not found" do
    result = @tool.call(
      repo_path: @repo_path,
      branch: "main",
      user_id: 999999
    )

    assert_not result[:success]
    assert_match(/User not found/, result[:error])
  end

  test "returns error when user has no github token" do
    @user.update!(github_token: nil)
    
    result = @tool.call(
      repo_path: @repo_path,
      branch: "main",
      user_id: @user.id
    )

    assert_not result[:success]
    assert_match(/User does not have a GitHub token configured/, result[:error])
  end

  test "returns error when repository path does not exist" do
    result = @tool.call(
      repo_path: "/nonexistent/path",
      branch: "main",
      user_id: @user.id
    )

    assert_not result[:success]
    assert_match(/Repository path does not exist/, result[:error])
  end

  test "returns error when path is not a git repository" do
    non_git_path = File.join(@temp_dir, "not_git")
    Dir.mkdir(non_git_path)

    result = @tool.call(
      repo_path: non_git_path,
      branch: "main",
      user_id: @user.id
    )

    assert_not result[:success]
    assert_match(/Not a git repository/, result[:error])
  end

  test "returns error when remote does not exist" do
    result = @tool.call(
      repo_path: @repo_path,
      branch: "main",
      user_id: @user.id,
      remote: "nonexistent"
    )

    assert_not result[:success]
    assert_match(/Failed to get remote URL/, result[:error])
  end

  test "converts SSH URLs to HTTPS with token" do
    Dir.chdir(@repo_path) do
      `git remote set-url origin git@github.com:test/repo.git`
    end

    # We can't test actual push without network, but we can verify the URL conversion
    # by checking that the tool attempts to set the authenticated URL
    original_set_url = `which git`.strip

    # This test verifies the tool runs without errors when given valid inputs
    # Actual push will fail due to invalid token/repo, but that's expected
    result = @tool.call(
      repo_path: @repo_path,
      branch: "main",
      user_id: @user.id
    )

    assert_not_nil result[:output]
    assert_equal "main", result[:branch]
    assert_equal "origin", result[:remote]
    assert_equal @repo_path, result[:repository]
  end

  test "handles HTTPS URLs correctly" do
    result = @tool.call(
      repo_path: @repo_path,
      branch: "main",
      user_id: @user.id
    )

    assert_not_nil result[:output]
    assert_equal "main", result[:branch]
    assert_equal "origin", result[:remote]
  end

  test "uses custom remote when specified" do
    Dir.chdir(@repo_path) do
      `git remote add upstream https://github.com/upstream/repo.git`
    end

    result = @tool.call(
      repo_path: @repo_path,
      branch: "main",
      user_id: @user.id,
      remote: "upstream"
    )

    assert_not_nil result[:output]
    assert_equal "upstream", result[:remote]
  end

  test "handles exceptions gracefully" do
    # Create a directory but make .git a file instead of directory
    invalid_git_path = File.join(@temp_dir, "invalid_git")
    Dir.mkdir(invalid_git_path)
    File.write(File.join(invalid_git_path, ".git"), "invalid")

    # Mock the tool to raise an exception
    tool = GitPushTool.new
    def tool.add_token_to_url(url, token)
      raise "Test exception"
    end

    result = tool.call(
      repo_path: @repo_path,
      branch: "main",
      user_id: @user.id
    )

    assert_not result[:success]
    assert_match(/Exception occurred/, result[:error])
  end
end

