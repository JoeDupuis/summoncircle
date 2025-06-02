require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "role enum works" do
    user = User.new(email_address: "test@example.com", password: "secret", password_confirmation: "secret")
    assert_nil user.role

    user.role = :admin
    assert user.admin?

    user.role = :standard
    assert user.standard?
  end

  test "git_config_file_path creates temporary file when git_config is present" do
    user = users(:one)
    user.git_config = "[user]\n    name = Test User\n    email = test@example.com"

    file_path = user.git_config_file_path
    assert_not_nil file_path
    assert File.exist?(file_path)

    content = File.read(file_path)
    assert_includes content, "name = Test User"
    assert_includes content, "email = test@example.com"

    user.cleanup_git_config_file
  end

  test "git_config_file_path returns nil when git_config is blank" do
    user = users(:one)
    user.git_config = nil

    assert_nil user.git_config_file_path
  end

  test "git_config_bind_string returns correct bind string" do
    user = users(:one)
    user.git_config = "[user]\n    name = Test User"
    agent = agents(:one)
    agent.home_path = "/home"

    bind_string = user.git_config_bind_string(agent)
    assert_not_nil bind_string
    assert_includes bind_string, ":/home/.gitconfig:ro"

    user.cleanup_git_config_file
  end

  test "git_config_bind_string returns nil when git_config is blank" do
    user = users(:one)
    user.git_config = nil
    agent = agents(:one)

    assert_nil user.git_config_bind_string(agent)
  end

  test "git_config_bind_string returns nil when agent home_path is blank" do
    user = users(:one)
    user.git_config = "[user]\n    name = Test User"
    agent = agents(:one)
    agent.home_path = nil

    assert_nil user.git_config_bind_string(agent)
  end

  test "git_config_bind_string returns nil when agent is nil" do
    user = users(:one)
    user.git_config = "[user]\n    name = Test User"

    assert_nil user.git_config_bind_string(nil)
  end

  test "cleanup_git_config_file removes temporary file" do
    user = users(:one)
    user.git_config = "[user]\n    name = Test User"

    file_path = user.git_config_file_path
    assert File.exist?(file_path)

    user.cleanup_git_config_file
    assert_not File.exist?(file_path)
  end
end
