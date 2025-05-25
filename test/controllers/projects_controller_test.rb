require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:one)
    @user = users(:one)
  end

  test "index requires authentication" do
    get projects_url
    assert_redirected_to new_session_path

    login @user
    get projects_url
    assert_response :success
  end

  test "new requires authentication" do
    get new_project_url
    assert_redirected_to new_session_path

    login @user
    get new_project_url
    assert_response :success
  end

  test "create requires authentication" do
    post projects_url, params: { project: { name: "Test", description: "Desc", repository_url: "http://example.com", setup_script: "echo hi" } }
    assert_redirected_to new_session_path

    login @user
    assert_difference("Project.count") do
      post projects_url, params: { project: { name: "Test", description: "Desc", repository_url: "http://example.com", setup_script: "echo hi" } }
    end
    assert_redirected_to project_path(Project.last)
  end

  test "show requires authentication" do
    get project_url(@project)
    assert_redirected_to new_session_path

    login @user
    get project_url(@project)
    assert_response :success
  end
end
