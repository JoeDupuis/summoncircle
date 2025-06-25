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
    post agents_url, params: { agent: { name: "Test", docker_image: "img", workplace_path: "/workspace" } }
    assert_redirected_to new_session_path

    login @user
    assert_difference("Agent.count") do
      post agents_url, params: { agent: { name: "Test", docker_image: "img", workplace_path: "/workspace" } }
    end
    assert_redirected_to agent_path(Agent.last)
  end

  test "create persists json arguments" do
    login @user
    post agents_url, params: { agent: { name: "Args", docker_image: "img", workplace_path: "/workspace", start_arguments: "[\"a\", \"b\"]", continue_arguments: "[1]" } }
    agent = Agent.last
    assert_equal [ "a", "b" ], agent.start_arguments
    assert_equal [ 1 ], agent.continue_arguments
  end

  test "create persists environment variables" do
    login @user
    env_config = '{"NODE_ENV": "development", "DEBUG": "true"}'
    post agents_url, params: { agent: { name: "EnvTest", docker_image: "img", workplace_path: "/workspace", env_variables_json: env_config } }
    agent = Agent.last
    assert_equal 2, agent.env_variables.count
    assert_equal "development", agent.env_variables.find_by(key: "NODE_ENV").value
    assert_equal "true", agent.env_variables.find_by(key: "DEBUG").value
  end

  test "create persists mcp_sse_endpoint" do
    login @user
    post agents_url, params: { agent: { name: "MCPTest", docker_image: "img", workplace_path: "/workspace", mcp_sse_endpoint: "http://localhost:3001" } }
    agent = Agent.last
    assert_equal "http://localhost:3001", agent.mcp_sse_endpoint
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

  test "update persists mcp_sse_endpoint" do
    login @user
    patch agent_url(@agent), params: { agent: { mcp_sse_endpoint: "http://localhost:4000/mcp/sse" } }
    assert_redirected_to agent_path(@agent)
    @agent.reload
    assert_equal "http://localhost:4000/mcp/sse", @agent.mcp_sse_endpoint
  end

  test "destroy requires authentication" do
    delete agent_url(@agent)
    assert_redirected_to new_session_path

    login @user
    assert_difference("Agent.kept.count", -1) do
      delete agent_url(@agent)
    end
    assert_redirected_to agents_path
    assert @agent.reload.discarded?
  end

  test "cloning agent with agent_specific_settings" do
    login @user

    # Create source agent with agent specific setting
    source_agent = Agent.create!(
      name: "Source Agent",
      docker_image: "test:latest",
      workplace_path: "/workspace",
      user_id: 1000
    )
    source_agent.agent_specific_settings.create!(type: "ClaudeOauthSetting")

    # Visit new agent page with source_id parameter (cloning)
    get new_agent_url(source_id: source_agent.id)
    assert_response :success

    # Create cloned agent
    assert_difference("Agent.count") do
      assert_difference("AgentSpecificSetting.count") do
        post agents_url, params: {
          agent: {
            name: "Copy of Source Agent",
            docker_image: "test:latest",
            workplace_path: "/workspace",
            agent_specific_setting_type: "ClaudeOauthSetting",
            agent_specific_settings_attributes: {
              "0" => {
                type: "ClaudeOauthSetting",
                _destroy: "false"
              }
            }
          }
        }
      end
    end

    cloned_agent = Agent.last
    assert_redirected_to agent_path(cloned_agent)
    assert_equal "Copy of Source Agent", cloned_agent.name
    assert_equal 1, cloned_agent.agent_specific_settings.count
    assert_equal "ClaudeOauthSetting", cloned_agent.agent_specific_settings.first.type
  end
end
