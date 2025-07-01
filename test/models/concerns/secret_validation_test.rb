require "test_helper"

class SecretValidationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "should not allow programming keywords as secret values" do
    invalid_values = %w[els else elsif if end then when case class module def]

    invalid_values.each do |value|
      secret = Secret.new(key: "TEST", value: value, secretable: @user)
      assert_not secret.valid?, "Secret should not be valid with value '#{value}'"
      assert_includes secret.errors[:value], "cannot be a reserved programming keyword to prevent code corruption"
    end
  end

  test "should allow normal secret values" do
    valid_values = [ "my_secret_123", "longersecretvalue", "SECRET_KEY", "123456", "short" ]

    valid_values.each do |value|
      secret = Secret.new(key: "TEST_#{value}", value: value, secretable: @user)
      assert secret.valid?, "Secret should be valid with value '#{value}': #{secret.errors.full_messages.join(', ')}"
    end
  end

  test "should not restrict long values that contain keywords" do
    secret = Secret.new(key: "TEST", value: "this_contains_else_but_is_long", secretable: @user)
    assert secret.valid?, "Long values containing keywords should be allowed"
  end

  test "should apply same validation to env variables" do
    agent = agents(:one)

    env_var = EnvVariable.new(key: "TEST", value: "else", envable: agent)
    assert_not env_var.valid?
    assert_includes env_var.errors[:value], "cannot be a reserved programming keyword to prevent code corruption"

    env_var.value = "valid_value"
    assert env_var.valid?
  end
end