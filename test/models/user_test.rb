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
end
