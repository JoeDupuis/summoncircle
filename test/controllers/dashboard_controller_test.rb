require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "root requires authentication" do
    get root_url
    assert_redirected_to new_session_path

    login @user
    get root_url
    assert_response :success
    assert_match projects_path, @response.body
    assert_match agents_path, @response.body
  end
end
