require "test_helper"

class ClaudeOauthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agent = agents(:one)
    @user = users(:one)
    login @user
  end

  test "should get login_start" do
    # Mock the oauth to avoid Docker calls in tests
    ClaudeOauth.any_instance.stubs(:login_start).returns("https://claude.ai/oauth/authorize?test=1")

    get oauth_login_start_agent_url(@agent)
    assert_response :success
  end

  test "should redirect login_finish without code" do
    post oauth_login_finish_agent_url(@agent)
    assert_redirected_to @agent
    assert_equal "No authorization code provided", flash[:alert]
  end

  test "should handle login_finish with code" do
    ClaudeOauth.any_instance.stubs(:login_finish).returns(true)

    post oauth_login_finish_agent_url(@agent, code: "test_code")
    assert_redirected_to @agent
    assert_equal "OAuth login successful!", flash[:notice]
  end

  test "should refresh tokens" do
    ClaudeOauth.any_instance.stubs(:check_credentials_exist).returns(true)
    ClaudeOauth.any_instance.stubs(:refresh_token).returns(true)

    post oauth_refresh_agent_url(@agent)
    assert_redirected_to @agent
    assert_equal "OAuth tokens refreshed successfully!", flash[:notice]
  end
end
