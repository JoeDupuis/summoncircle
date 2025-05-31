require "test_helper"

class AgentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agent = agents(:one)
    @user = users(:one)
  end

  test "index requires authentication" do
    get agents_url
    assert_redirected_to new_session_path

    login @user
    get agents_url
    assert_response :success
  end

  test "new requires authentication" do
    get new_agent_url
    assert_redirected_to new_session_path

    login @user
    get new_agent_url
    assert_response :success
  end

  test "create requires authentication" do
    post agents_url, params: { agent: { name: "Test", docker_image: "img" } }
    assert_redirected_to new_session_path

    login @user
    assert_difference("Agent.count") do
      post agents_url, params: { agent: { name: "Test", docker_image: "img" } }
    end
    assert_redirected_to agent_path(Agent.last)
  end

  test "create persists json arguments" do
    login @user
    post agents_url, params: { agent: { name: "Args", docker_image: "img", start_arguments: "[\"a\", \"b\"]", continue_arguments: "[1]" } }
    agent = Agent.last
    assert_equal [ "a", "b" ], agent.start_arguments
    assert_equal [ 1 ], agent.continue_arguments
  end

  test "create persists environment variables" do
    login @user
    env_config = '{"NODE_ENV": "development", "DEBUG": "true"}'
    post agents_url, params: { agent: { name: "EnvTest", docker_image: "img", env_variables: env_config } }
    agent = Agent.last
    assert_equal({ "NODE_ENV" => "development", "DEBUG" => "true" }, agent.environment_variables)
  end

  test "show requires authentication" do
    get agent_url(@agent)
    assert_redirected_to new_session_path

    login @user
    get agent_url(@agent)
    assert_response :success
  end

  test "edit requires authentication" do
    get edit_agent_url(@agent)
    assert_redirected_to new_session_path

    login @user
    get edit_agent_url(@agent)
    assert_response :success
  end

  test "update requires authentication" do
    patch agent_url(@agent), params: { agent: { name: "Updated" } }
    assert_redirected_to new_session_path

    login @user
    patch agent_url(@agent), params: { agent: { name: "Updated" } }
    assert_redirected_to agent_path(@agent)
    @agent.reload
    assert_equal "Updated", @agent.name
  end

  test "destroy requires authentication" do
    delete agent_url(@agent)
    assert_redirected_to new_session_path

    login @user
    assert_difference("Agent.count", -1) do
      delete agent_url(@agent)
    end
    assert_redirected_to agents_path
  end
end
