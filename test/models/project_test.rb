require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "validates presence of name" do
    project = Project.new(repository_url: "https://example.com/repo.git")
    assert_not project.valid?
    assert_includes project.errors[:name], "can't be blank"
  end

  test "allows blank repository_url" do
    project = Project.new(name: "Example")
    assert project.valid?
    assert_nil project.repository_url
  end

  test "validates HTTPS repository URLs" do
    project = Project.new(name: "Example", repository_url: "https://github.com/user/repo.git")
    assert project.valid?
  end

  test "validates HTTP repository URLs" do
    project = Project.new(name: "Example", repository_url: "http://github.com/user/repo.git")
    assert project.valid?
  end

  test "validates SSH repository URLs with git@ format" do
    project = Project.new(name: "Example", repository_url: "git@github.com:JoeDupuis/shenanigans.git")
    assert project.valid?
  end

  test "validates SSH repository URLs with ssh:// format" do
    project = Project.new(name: "Example", repository_url: "ssh://git@github.com:JoeDupuis/shenanigans.git")
    assert project.valid?
  end

  test "rejects invalid repository URLs" do
    invalid_urls = [
      "ftp://example.com/repo.git",
      "not-a-url",
      "git@github.com:user/repo",  # Missing .git
      "github.com:user/repo.git",   # Missing git@
      "https://",
      "http://"
    ]

    invalid_urls.each do |url|
      project = Project.new(name: "Example", repository_url: url)
      assert_not project.valid?, "Expected #{url} to be invalid"
      assert_includes project.errors[:repository_url], "must be a valid HTTP, HTTPS, or SSH git URL"
    end
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

  test "nested attributes creates new secrets" do
    project = projects(:one)
    
    project.update(secrets_attributes: [
      { key: "API_KEY", value: "secret_value" },
      { key: "DB_PASSWORD", value: "db_secret" }
    ])

    assert_equal 2, project.secrets.count
    assert_equal "secret_value", project.secrets.find_by(key: "API_KEY").value
    assert_equal "db_secret", project.secrets.find_by(key: "DB_PASSWORD").value
  end

  test "nested attributes updates existing secrets" do
    project = projects(:one)
    secret = project.secrets.create!(key: "API_KEY", value: "old_value")

    project.update(secrets_attributes: [
      { id: secret.id, key: "API_KEY", value: "new_value" }
    ])

    assert_equal 1, project.secrets.count
    assert_equal "new_value", project.secrets.find_by(key: "API_KEY").value
  end

  test "nested attributes rejects all blank entries" do
    project = projects(:one)
    
    project.update(secrets_attributes: [
      { key: "", value: "" },  # This will be rejected
      { key: "VALID_KEY", value: "valid_value" }
    ])

    assert_equal 1, project.secrets.count
    assert_equal "valid_value", project.secrets.find_by(key: "VALID_KEY").value
  end

  test "secrets_hash returns key-value pairs" do
    project = projects(:one)
    project.secrets.create!(key: "API_KEY", value: "secret_value")
    project.secrets.create!(key: "DB_PASSWORD", value: "db_secret")

    expected = { "API_KEY" => "secret_value", "DB_PASSWORD" => "db_secret" }
    assert_equal expected, project.secrets_hash
  end

  test "secret_values returns array of values" do
    project = projects(:one)
    project.secrets.create!(key: "API_KEY", value: "secret_value")
    project.secrets.create!(key: "DB_PASSWORD", value: "db_secret")

    values = project.secret_values
    assert_includes values, "secret_value"
    assert_includes values, "db_secret"
    assert_equal 2, values.length
  end
end
