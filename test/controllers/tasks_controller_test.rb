require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:one)
    @agent = agents(:one)
    @task = tasks(:one)
    @user = users(:one)
  end

  test "index requires authentication" do
    get project_tasks_url(@project)
    assert_redirected_to new_session_path

    login @user
    get project_tasks_url(@project)
    assert_response :success
  end

  test "new requires authentication" do
    get new_project_task_url(@project)
    assert_redirected_to new_session_path

    login @user
    get new_project_task_url(@project)
    assert_response :success
  end

  test "create requires authentication" do
    post project_tasks_url(@project), params: { task: { agent_id: @agent.id, prompt: "hi" } }
    assert_redirected_to new_session_path

    login @user
    assert_difference([ "Task.count", "Run.count" ]) do
      post project_tasks_url(@project), params: { task: { agent_id: @agent.id, prompt: "hi" } }
    end
    assert_redirected_to project_task_path(@project, Task.last)
  end

  test "show requires authentication" do
    get project_task_url(@project, @task)
    assert_redirected_to new_session_path

    login @user
    get project_task_url(@project, @task)
    assert_response :success
  end
end
