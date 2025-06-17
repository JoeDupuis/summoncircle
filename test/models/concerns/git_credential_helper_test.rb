require "test_helper"

class GitCredentialHelperTest < ActiveSupport::TestCase
  class TestClass
    include GitCredentialHelper
  end

  setup do
    @helper = TestClass.new
  end

  test "setup_git_credentials does not modify config when no token present" do
    container_config = {
      "Image" => "test:latest",
      "Cmd" => [ "-c", "git clone repo" ]
    }

    user = mock("user")
    user.stubs(:github_token).returns(nil)

    result = @helper.setup_git_credentials(container_config, user, "https://github.com/test/repo.git")

    assert_equal container_config["Image"], result["Image"]
    assert_nil result["Env"]
  end

  test "setup_git_credentials adds environment variables when token present" do
    container_config = {
      "Image" => "test:latest",
      "Cmd" => [ "-c", "git clone repo" ]
    }

    user = mock("user")
    user.stubs(:github_token).returns("test_token_123")

    result = @helper.setup_git_credentials(container_config, user, "https://github.com/test/repo.git")

    assert_includes result["Env"], "GITHUB_TOKEN=test_token_123"
    assert_includes result["Env"], "GIT_ASKPASS=/tmp/git-askpass.sh"
  end

  test "setup_git_credentials wraps command with credential setup" do
    container_config = {
      "Image" => "test:latest",
      "Cmd" => [ "-c", "git clone repo" ]
    }

    user = mock("user")
    user.stubs(:github_token).returns("test_token_123")

    result = @helper.setup_git_credentials(container_config, user, "https://github.com/test/repo.git")

    assert_equal "-c", result["Cmd"][0]
    cmd = result["Cmd"][1]
    assert_includes cmd, "/tmp/git-askpass.sh"
    assert_includes cmd, "chmod +x /tmp/git-askpass.sh"
    assert_includes cmd, "git clone repo"
  end

  test "git askpass script returns correct values" do
    container_config = {
      "Image" => "test:latest",
      "Cmd" => [ "-c", "git clone repo" ]
    }

    user = mock("user")
    user.stubs(:github_token).returns("test_token_123")

    result = @helper.setup_git_credentials(container_config, user, "https://github.com/test/repo.git")
    cmd = result["Cmd"][1]

    assert_match(/Username.*echo "x-access-token"/, cmd)
    assert_match(/Password.*echo "\$GITHUB_TOKEN"/, cmd)
  end

  test "setup_git_credentials returns unmodified config for non-github URLs" do
    container_config = {
      "Image" => "test:latest",
      "Cmd" => [ "-c", "git clone repo" ]
    }

    user = mock("user")
    user.stubs(:github_token).returns("test_token_123")

    result = @helper.setup_git_credentials(container_config, user, "https://example.com/test/repo.git")

    assert_equal container_config, result
  end
end
