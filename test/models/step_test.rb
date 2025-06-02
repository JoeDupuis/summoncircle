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

    user.cleanup_ssh_key_file
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

    user.cleanup_ssh_key_file
  end
end
