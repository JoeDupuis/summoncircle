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

  test "log_processor defaults to Text" do
    agent = Agent.new(name: "Name", docker_image: "img")
    assert_equal "Text", agent.log_processor
  end

  test "log_processor_class returns correct class" do
    agent = Agent.new(name: "Name", docker_image: "img", log_processor: "Text")
    assert_equal LogProcessor::Text, agent.log_processor_class

    agent.log_processor = "ClaudeStreamingJson"
    assert_equal LogProcessor::ClaudeStreamingJson, agent.log_processor_class
  end

  test "log_processor_class raises error for invalid processor" do
    agent = Agent.new(name: "Name", docker_image: "img", log_processor: "InvalidProcessor")
    assert_raises(NameError) { agent.log_processor_class }
  end
end
