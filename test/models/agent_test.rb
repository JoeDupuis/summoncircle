require "test_helper"

class AgentTest < ActiveSupport::TestCase
  test "fixture is valid" do
    agent = agents(:one)
    assert agent.valid?
  end

  test "requires name, docker image, and workplace_path" do
    agent = Agent.new(start_arguments: {}, continue_arguments: {})
    assert_not agent.valid?
    assert_includes agent.errors[:name], "can't be blank"
    assert_includes agent.errors[:docker_image], "can't be blank"
    assert_includes agent.errors[:workplace_path], "can't be blank"
  end

  test "name, docker image, and workplace_path are sufficient" do
    agent = Agent.new(name: "Name", docker_image: "img", workplace_path: "/workspace")
    assert_valid agent
  end

  test "log_processor defaults to Text" do
    agent = Agent.new(name: "Name", docker_image: "img", workplace_path: "/workspace")
    assert_equal "Text", agent.log_processor
  end

  test "log_processor_class returns correct class" do
    agent = Agent.new(name: "Name", docker_image: "img", workplace_path: "/workspace", log_processor: "Text")
    assert_equal LogProcessor::Text, agent.log_processor_class

    agent.log_processor = "ClaudeJson"
    assert_equal LogProcessor::ClaudeJson, agent.log_processor_class
  end

  test "log_processor_class raises error for invalid processor" do
    agent = Agent.new(name: "Name", docker_image: "img", workplace_path: "/workspace", log_processor: "InvalidProcessor")
    assert_raises(NameError) { agent.log_processor_class }
  end
end
