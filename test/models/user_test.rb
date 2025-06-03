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
end
