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
end
