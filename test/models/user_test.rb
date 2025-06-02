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

  test "ssh_key is encrypted" do
    user = users(:one)
    ssh_key_content = "-----BEGIN OPENSSH PRIVATE KEY-----\ntest_key_content\n-----END OPENSSH PRIVATE KEY-----"

    user.update!(ssh_key: ssh_key_content)
    user.reload

    assert_equal ssh_key_content, user.ssh_key
    assert_not_equal ssh_key_content, user.read_attribute_before_type_cast(:ssh_key)
  end

  test "ssh_key_file_path creates temporary file with correct permissions" do
    user = users(:one)
    ssh_key_content = "-----BEGIN OPENSSH PRIVATE KEY-----\ntest_key_content\n-----END OPENSSH PRIVATE KEY-----"
    user.update!(ssh_key: ssh_key_content)

    file_path = user.ssh_key_file_path
    assert File.exist?(file_path)
    assert_equal ssh_key_content, File.read(file_path)

    file_stat = File.stat(file_path)
    assert_equal 0o600, file_stat.mode & 0o777

    user.cleanup_ssh_key_file
  end

  test "ssh_key_bind_string returns correct bind string" do
    user = users(:one)
    ssh_key_content = "-----BEGIN OPENSSH PRIVATE KEY-----\ntest_key_content\n-----END OPENSSH PRIVATE KEY-----"
    user.update!(ssh_key: ssh_key_content)

    bind_string = user.ssh_key_bind_string("/home/user/.ssh/id_rsa")
    assert bind_string.include?(":ro")
    assert bind_string.include?(":/home/user/.ssh/id_rsa")

    user.cleanup_ssh_key_file
  end

  test "ssh_key_bind_string returns nil when no ssh_key" do
    user = users(:one)
    user.update!(ssh_key: nil)

    assert_nil user.ssh_key_bind_string("/home/user/.ssh/id_rsa")
  end

  test "ssh_key_bind_string returns nil when no mount_path" do
    user = users(:one)
    ssh_key_content = "-----BEGIN OPENSSH PRIVATE KEY-----\ntest_key_content\n-----END OPENSSH PRIVATE KEY-----"
    user.update!(ssh_key: ssh_key_content)

    assert_nil user.ssh_key_bind_string(nil)
    assert_nil user.ssh_key_bind_string("")

    user.cleanup_ssh_key_file
  end

  test "cleanup_ssh_key_file removes temporary file" do
    user = users(:one)
    ssh_key_content = "-----BEGIN OPENSSH PRIVATE KEY-----\ntest_key_content\n-----END OPENSSH PRIVATE KEY-----"
    user.update!(ssh_key: ssh_key_content)

    file_path = user.ssh_key_file_path
    assert File.exist?(file_path)

    user.cleanup_ssh_key_file
    assert_not File.exist?(file_path)
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
