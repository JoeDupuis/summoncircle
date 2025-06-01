require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "validates presence of name" do
    project = Project.new(repository_url: "https://example.com/repo.git")
    assert_not project.valid?
    assert_includes project.errors[:name], "can't be blank"
  end

  test "validates presence of repository_url" do
    project = Project.new(name: "Example")
    assert_not project.valid?
    assert_includes project.errors[:repository_url], "can't be blank"
  end

  test "repo_path can be nil" do
    project = Project.new(name: "Example", repository_url: "https://example.com/repo.git")
    assert project.valid?
    assert_nil project.repo_path
  end

  test "repo_path can be set" do
    project = Project.new(name: "Example", repository_url: "https://example.com/repo.git", repo_path: "myapp")
    assert project.valid?
    assert_equal "myapp", project.repo_path
  end
end
