require "test_helper"

class StepTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    step = Step.new(
      run: runs(:one),
      raw_response: "Hello"
    )
    assert step.valid?
  end

  test "should require run" do
    step = Step.new(raw_response: "text")
    assert_not step.valid?
    assert_includes step.errors[:run], "must exist"
  end

  test "should require raw_response" do
    step = Step.new(run: runs(:one))
    assert_not step.valid?
    assert_includes step.errors[:raw_response], "can't be blank"
  end

  test "run should have many steps" do
    run = runs(:one)
    assert_respond_to run, :steps
    assert_kind_of ActiveRecord::Associations::CollectionProxy, run.steps
  end

  test "destroying run should destroy associated steps" do
    run = runs(:one)
    initial_step_count = run.steps.count
    step = Step.create!(
      run: run,
      raw_response: "Test"
    )

    assert_difference "Step.count", -(initial_step_count + 1) do
      run.destroy
    end
  end

  test "parsed_response should return parsed JSON" do
    json_data = { "message" => "hello", "status" => "success" }
    step = Step.new(
      run: runs(:one),
      raw_response: json_data.to_json
    )

    assert_equal json_data, step.parsed_response
  end

  test "parsed_response should return raw_response for invalid JSON" do
    step = Step.new(
      run: runs(:one),
      raw_response: "invalid json"
    )

    assert_equal "invalid json", step.parsed_response
  end

  test "has many repo_states" do
    step = steps(:one)
    assert_respond_to step, :repo_states
    assert_kind_of ActiveRecord::Associations::CollectionProxy, step.repo_states
  end

  test "destroying step should destroy associated repo_states" do
    step = steps(:one)
    initial_repo_states_count = step.repo_states.count

    assert_difference "RepoState.count", -initial_repo_states_count do
      step.destroy
    end
  end

  test "content filters SSH key content" do
    user = users(:one)
    ssh_key_content = "-----BEGIN OPENSSH PRIVATE KEY-----\ntest_key_content\n-----END OPENSSH PRIVATE KEY-----"
    user.update!(ssh_key: ssh_key_content)

    task = tasks(:without_runs)
    task.update!(user: user)
    run = task.runs.create!(prompt: "test")

    content_with_key = "Some output\n-----BEGIN OPENSSH PRIVATE KEY-----\ntest_key_content\n-----END OPENSSH PRIVATE KEY-----\nMore output"
    step = Step.new(run: run, raw_response: "response", content: content_with_key)

    filtered_content = step.content

    assert_not_includes filtered_content, "-----BEGIN OPENSSH PRIVATE KEY-----"
    assert_not_includes filtered_content, "test_key_content"
    assert_not_includes filtered_content, "-----END OPENSSH PRIVATE KEY-----"
    assert_includes filtered_content, "[FILTERED]"
    assert_includes filtered_content, "Some output"
    assert_includes filtered_content, "More output"
  end

  test "raw_response filters SSH key content" do
    user = users(:one)
    ssh_key_content = "-----BEGIN OPENSSH PRIVATE KEY-----\ntest_key_content\n-----END OPENSSH PRIVATE KEY-----"
    user.update!(ssh_key: ssh_key_content)

    task = tasks(:without_runs)
    task.update!(user: user)
    run = task.runs.create!(prompt: "test")

    response_with_key = "Response with\n-----BEGIN OPENSSH PRIVATE KEY-----\ntest_key_content\n-----END OPENSSH PRIVATE KEY-----\nkey content"
    step = Step.new(run: run, raw_response: response_with_key)

    filtered_response = step.raw_response

    assert_not_includes filtered_response, "-----BEGIN OPENSSH PRIVATE KEY-----"
    assert_not_includes filtered_response, "test_key_content"
    assert_not_includes filtered_response, "-----END OPENSSH PRIVATE KEY-----"
    assert_includes filtered_response, "[FILTERED]"
    assert_includes filtered_response, "Response with"
    assert_includes filtered_response, "key content"
  end

  test "filters github token from content" do
    user = users(:one)
    user.update!(github_token: "github_token_123")

    step = Step.new(
      run: runs(:one),
      raw_response: "Error: github_token_123 is invalid"
    )
    step.write_attribute(:content, "Error: github_token_123 is invalid")

    assert_equal "Error: [FILTERED] is invalid", step.content
  end

  test "filters github token from raw_response" do
    user = users(:one)
    user.update!(github_token: "github_token_123")

    step = Step.create!(
      run: runs(:one),
      raw_response: "Error: github_token_123 is invalid"
    )

    assert_equal "Error: [FILTERED] is invalid", step.raw_response
  end

  test "filters project secrets from content" do
    project = projects(:one)
    project.secrets.create!(key: "API_KEY", value: "secret_api_key_123")
    project.secrets.create!(key: "DB_PASSWORD", value: "db_pass_456")

    step = Step.new(
      run: runs(:one),
      raw_response: "Connecting with secret_api_key_123 and db_pass_456"
    )
    step.write_attribute(:content, "Connecting with secret_api_key_123 and db_pass_456")

    assert_equal "Connecting with [FILTERED] and [FILTERED]", step.content
  end

  test "filters both github token and project secrets" do
    user = users(:one)
    user.update!(github_token: "github_token_123")

    project = projects(:one)
    project.secrets.create!(key: "API_KEY", value: "secret_api_key_123")

    step = Step.new(
      run: runs(:one),
      raw_response: "Using github_token_123 and secret_api_key_123"
    )
    step.write_attribute(:content, "Using github_token_123 and secret_api_key_123")

    assert_equal "Using [FILTERED] and [FILTERED]", step.content
  end

  test "does not filter when no secrets present" do
    step = Step.new(
      run: runs(:one),
      raw_response: "No secrets here"
    )
    step.write_attribute(:content, "No secrets here")

    assert_equal "No secrets here", step.content
  end

  test "pretty_raw_response should return pretty-printed JSON" do
    json_data = { "message" => "hello", "status" => "success", "data" => { "count" => 5 } }
    step = Step.new(
      run: runs(:one),
      raw_response: json_data.to_json
    )

    expected = JSON.pretty_generate(json_data)
    assert_equal expected, step.pretty_raw_response
  end

  test "pretty_raw_response should return raw_response for invalid JSON" do
    step = Step.new(
      run: runs(:one),
      raw_response: "invalid json"
    )

    assert_equal "invalid json", step.pretty_raw_response
  end
end
