require "test_helper"

class BuildLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:two)  # Use standard user, not admin
    @task = tasks(:two)
    login @user
  end

  test "should get show for own task" do
    get task_build_log_url(@task)
    assert_response :success
  end

  test "should access any task build logs when authenticated" do
    other_user_task = tasks(:one)  # This belongs to user one

    # Verify the task belongs to a different user
    assert_not_equal @user.id, other_user_task.user_id

    # Log in as user two and access user one's task - should work
    get task_build_log_url(other_user_task)
    assert_response :success
  end

  test "should redirect to login when not authenticated" do
    logout
    get task_build_log_url(@task)
    assert_redirected_to new_session_path
  end
end
