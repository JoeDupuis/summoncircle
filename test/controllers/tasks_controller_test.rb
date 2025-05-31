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

  test "show renders Step::Text with content" do
    login @user
    run = @task.runs.create!(prompt: "test")
    run.steps.create!(type: "Step::Text", content: "Hello world", raw_response: "raw data")

    get project_task_url(@project, @task)
    assert_response :success
    assert_select "pre", text: "Hello world"
  end

  test "show renders Step::Init with session initialized message" do
    login @user
    run = @task.runs.create!(prompt: "test")
    run.steps.create!(type: "Step::Init", content: nil, raw_response: '{"type":"system","subtype":"init"}')

    get project_task_url(@project, @task)
    assert_response :success
    assert_select "div strong", text: "🚀 Session Initialized"
  end

  test "show renders Step::ToolCall with tool call styling" do
    login @user
    run = @task.runs.create!(prompt: "test")
    content = "name: WebFetch\ninputs: {\"url\":\"https://example.com\",\"prompt\":\"What is the title of this webpage?\"}"
    run.steps.create!(type: "Step::ToolCall", content: content, raw_response: '{"type":"assistant"}')

    get project_task_url(@project, @task)
    assert_response :success
    assert_select "div strong", text: "🔧 Tool Call"
    assert_select "pre", text: content
  end

  test "show renders Step::ToolResult with tool result styling" do
    login @user
    run = @task.runs.create!(prompt: "test")
    run.steps.create!(type: "Step::ToolResult", content: "total 0", raw_response: '{"type":"user"}')

    get project_task_url(@project, @task)
    assert_response :success
    assert_select "div strong", text: "⚙️ Tool Result"
    assert_select "pre", text: "total 0"
  end

  test "show renders Step::Result with result styling" do
    login @user
    run = @task.runs.create!(prompt: "test")
    run.steps.create!(type: "Step::Result", content: "Task completed successfully", raw_response: '{"type":"result"}')

    get project_task_url(@project, @task)
    assert_response :success
    assert_select "div strong", text: "✅ Result"
    assert_select "pre", text: "Task completed successfully"
  end

  test "show renders Step::System with system styling" do
    login @user
    run = @task.runs.create!(prompt: "test")
    run.steps.create!(type: "Step::System", content: "System message", raw_response: '{"type":"system"}')

    get project_task_url(@project, @task)
    assert_response :success
    assert_select "div strong", text: "🔧 System"
    assert_select "pre", text: "System message"
  end

  test "show renders base Step with raw_response when no STI type" do
    login @user
    run = @task.runs.create!(prompt: "test")
    run.steps.create!(content: "some content", raw_response: "fallback raw data")

    get project_task_url(@project, @task)
    assert_response :success
    assert_select "pre", text: "fallback raw data"
  end
end
