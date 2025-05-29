require "test_helper"

class AgentTest < ActiveSupport::TestCase
  test "fixture is valid" do
    agent = agents(:one)
    assert agent.valid?
  end

  test "requires name and docker image" do
    agent = Agent.new(agent_prompt: "prompt", setup_script: "script", start_arguments: {}, continue_arguments: {})
    assert_not agent.valid?
    assert_includes agent.errors[:name], "can't be blank"
    assert_includes agent.errors[:docker_image], "can't be blank"
  end

  test "prompt and script are optional" do
    agent = Agent.new(name: "Name", docker_image: "img")
    assert_valid agent
  end

  test "docker_host is optional" do
    agent = Agent.new(name: "Test Agent", docker_image: "test/image")
    assert agent.valid?
  end

  test "can set docker_host" do
    agent = Agent.new(name: "Test Agent", docker_image: "test/image", docker_host: "tcp://192.168.1.100:2375")
    assert agent.valid?
    assert_equal "tcp://192.168.1.100:2375", agent.docker_host
  end
end
