require "test_helper"

class RepoStateTest < ActiveSupport::TestCase
  test "belongs to step" do
    repo_state = repo_states(:one)
    assert_equal steps(:one), repo_state.step
  end

  test "can store uncommitted diff" do
    repo_state = repo_states(:one)
    assert repo_state.uncommitted_diff.present?
    assert repo_state.uncommitted_diff.include?("has_many :projects")
  end

  test "can have empty uncommitted diff" do
    repo_state = repo_states(:two)
    assert_equal "", repo_state.uncommitted_diff
  end

  test "stores repository path" do
    repo_state = repo_states(:one)
    assert_equal "/workspace/myproject", repo_state.repository_path
  end

  test "should not filter sensitive content from diffs" do
    # Create a step with a repo state
    step = steps(:bash_tool)
    repo_state = step.repo_states.create!(
      repository_path: "/test/path",
      uncommitted_diff: "test diff",
      target_branch_diff: "target diff"
    )

    # Create a secret that could corrupt diffs
    Secret.create!(key: "TEST_SECRET", value: "els", secretable: step.run.task.user)

    # Create a diff that contains the secret value
    diff_with_else = <<~DIFF
      diff --git a/app/models/task.rb b/app/models/task.rb
      @@ -47,7 +47,14 @@ class Task < ApplicationRecord
      +    else
      +      Array(additional_vars)
    DIFF

    repo_state.update!(
      git_diff: diff_with_else,
      uncommitted_diff: diff_with_else,
      target_branch_diff: diff_with_else
    )

    # Reload to ensure we're getting from database
    repo_state.reload

    # Verify diffs are not corrupted (should still contain "else", not "e")
    assert_includes repo_state.git_diff, "else"
    assert_includes repo_state.uncommitted_diff, "else"
    assert_includes repo_state.target_branch_diff, "else"

    # Ensure the full word is preserved
    assert_not_includes repo_state.git_diff, "+    e\n"
    assert_not_includes repo_state.uncommitted_diff, "+    e\n"
    assert_not_includes repo_state.target_branch_diff, "+    e\n"
  end

  test "should preserve diff content exactly as stored" do
    step = steps(:bash_tool)
    repo_state = step.repo_states.create!(
      repository_path: "/test/path"
    )

    complex_diff = <<~DIFF
      diff --git a/file.rb b/file.rb
      @@ -1,3 +1,3 @@
      -    models = User.all
      +    models = User.where(active: true)
      +    # els should not be filtered
      +    else
    DIFF

    repo_state.update!(git_diff: complex_diff)
    repo_state.reload

    assert_equal complex_diff, repo_state.git_diff
  end
end
