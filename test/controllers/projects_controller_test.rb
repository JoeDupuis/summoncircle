require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:one)
  end

  test "should get index" do
    get projects_url
    assert_response :success
  end

  test "should get new" do
    get new_project_url
    assert_response :success
  end

  test "should create project" do
    assert_difference("Project.count") do
      post projects_url, params: { project: { name: "Test", description: "Desc", repository_url: "http://example.com", setup_script: "echo hi" } }
    end

    assert_redirected_to project_path(Project.last)
  end

  test "should show project" do
    get project_url(@project)
    assert_response :success
  end
end
