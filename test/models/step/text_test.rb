require "test_helper"

class Step::TextTest < ActiveSupport::TestCase
  test "stores and retrieves content" do
    run = runs(:one)
    step = Step::Text.create!(
      run: run,
      raw_response: '{"type": "text", "content": "# Hello World"}',
      content: "# Hello World"
    )

    assert_equal "# Hello World", step.content
  end

  test "inherits filtering from Step base class" do
    user = users(:one)
    user.update!(github_token: "ghp_secret123")
    task = tasks(:one)
    task.update!(user: user)
    run = runs(:one)
    run.update!(task: task)

    step = Step::Text.create!(
      run: run,
      raw_response: '{"type": "text", "content": "Token: ghp_secret123"}',
      content: "Token: ghp_secret123"
    )

    assert_equal "Token: [FILTERED]", step.content
  end
end
