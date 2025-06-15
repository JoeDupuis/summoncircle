require "test_helper"

class ClaudeOauthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agent = agents(:one)
    @user = users(:one)
    login @user
  end

  test "should get login_start" do
    get oauth_login_start_agent_url(@agent)
    assert_response :success
  end

  test "should redirect login_finish without code" do
    post oauth_login_finish_agent_url(@agent)
    assert_redirected_to @agent
    assert_equal "No authorization code provided", flash[:alert]
  end

  test "should refresh tokens" do
    @agent.update(oauth_credentials: {
      "claudeAiOauth" => {
        "accessToken" => "test_token",
        "refreshToken" => "test_refresh_token",
        "expiresAt" => 1.hour.from_now.to_i * 1000
      }
    }.to_json)

    post oauth_refresh_agent_url(@agent)
    assert_redirected_to @agent
  end
end