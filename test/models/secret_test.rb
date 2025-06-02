require "test_helper"

class SecretTest < ActiveSupport::TestCase
  test "validates presence of key" do
    secret = Secret.new(project: projects(:one), value: "secret_value")
    assert_not secret.valid?
    assert_includes secret.errors[:key], "can't be blank"
  end

  test "validates presence of value" do
    secret = Secret.new(project: projects(:one), key: "API_KEY")
    assert_not secret.valid?
    assert_includes secret.errors[:value], "can't be blank"
  end

  test "validates uniqueness of key within project" do
    project = projects(:one)
    Secret.create!(project: project, key: "API_KEY", value: "secret1")

    duplicate_secret = Secret.new(project: project, key: "API_KEY", value: "secret2")
    assert_not duplicate_secret.valid?
    assert_includes duplicate_secret.errors[:key], "has already been taken"
  end

  test "allows same key in different projects" do
    project1 = projects(:one)
    project2 = projects(:two)

    Secret.create!(project: project1, key: "API_KEY", value: "secret1")
    secret2 = Secret.new(project: project2, key: "API_KEY", value: "secret2")

    assert secret2.valid?
  end

  test "encrypts value" do
    secret = Secret.create!(project: projects(:one), key: "API_KEY", value: "secret_value")

    assert_not_equal "secret_value", secret.read_attribute_before_type_cast(:value)
    assert_equal "secret_value", secret.value
  end
end
