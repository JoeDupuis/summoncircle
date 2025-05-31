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

  test "env_variables can store JSON data" do
    agent = Agent.new(name: "Name", docker_image: "img")
    env_vars = { "NODE_ENV" => "development", "DEBUG" => "true" }
    agent.env_variables = env_vars
    agent.save!

    agent.reload
    assert_equal env_vars, agent.env_variables
  end

  test "env_variables_json returns JSON string" do
    agent = Agent.new(name: "Name", docker_image: "img")
    env_vars = { "NODE_ENV" => "development", "DEBUG" => "true" }
    agent.env_variables = env_vars

    assert_equal env_vars.to_json, agent.env_variables_json
  end

  test "env_variables_json returns empty string when nil" do
    agent = Agent.new(name: "Name", docker_image: "img")
    assert_equal "", agent.env_variables_json
  end

  test "env_variables_json= parses JSON and sets env_variables" do
    agent = Agent.new(name: "Name", docker_image: "img")
    json_string = '{"NODE_ENV": "development", "DEBUG": "true"}'
    agent.env_variables_json = json_string

    expected = { "NODE_ENV" => "development", "DEBUG" => "true" }
    assert_equal expected, agent.env_variables
  end

  test "env_variables_json= adds error for invalid JSON" do
    agent = Agent.new(name: "Name", docker_image: "img")
    agent.env_variables_json = "invalid json"

    assert_includes agent.errors[:env_variables_json], "must be valid JSON"
  end

  test "env_strings returns Docker-formatted environment variables" do
    agent = Agent.new(name: "Name", docker_image: "img")
    agent.env_variables = { "NODE_ENV" => "development", "DEBUG" => "true" }

    expected = [ "NODE_ENV=development", "DEBUG=true" ]
    assert_equal expected, agent.env_strings
  end

  test "env_strings returns empty array when no environment variables" do
    agent = Agent.new(name: "Name", docker_image: "img")
    assert_equal [], agent.env_strings
  end
end
