require "test_helper"

class ToolCallViewTest < ActionView::TestCase
  test "renders bash tool call with terminal styling" do
    run = runs(:one)
    bash_content = "name: Bash\ninputs: {\"command\":\"ls -la\",\"description\":\"List files with details\"}"

    tool_call = Step::ToolCall.create!(
      run: run,
      raw_response: '{"type":"tool_call"}',
      content: bash_content
    )

    rendered = render(partial: "step/tool_calls/tool_call", locals: { tool_call: tool_call })

    assert_includes rendered, "bash-tool-call"
    assert_includes rendered, "bash-prompt"
    assert_includes rendered, "prompt-symbol"
    assert_includes rendered, "ls -la"
    assert_includes rendered, "List files with details"
  end

  test "renders non-bash tool call with standard styling" do
    run = runs(:one)
    web_fetch_content = "name: WebFetch\ninputs: {\"url\":\"https://example.com\",\"prompt\":\"Get title\"}"

    tool_call = Step::ToolCall.create!(
      run: run,
      raw_response: '{"type":"tool_call"}',
      content: web_fetch_content
    )

    rendered = render(partial: "step/tool_calls/tool_call", locals: { tool_call: tool_call })

    assert_includes rendered, "tool-call"
    assert_includes rendered, "🔧 Tool Call"
    assert_includes rendered, "content"
    assert_not_includes rendered, "bash-tool-call"
  end

  test "handles bash tool call without description" do
    run = runs(:one)
    bash_content = "name: Bash\ninputs: {\"command\":\"pwd\"}"

    tool_call = Step::ToolCall.create!(
      run: run,
      raw_response: '{"type":"tool_call"}',
      content: bash_content
    )

    rendered = render(partial: "step/tool_calls/tool_call", locals: { tool_call: tool_call })

    assert_includes rendered, "pwd"
    assert_not_includes rendered, "bash-description"
  end
end
