require "test_helper"

class BashCommandViewTest < ActionView::TestCase
  test "renders bash command with terminal styling" do
    run = runs(:one)
    bash_content = "name: Bash\ninputs: {\"command\":\"ls -la\",\"description\":\"List files with details\"}"

    bash_command = Step::BashCommand.create!(
      run: run,
      raw_response: '{"type":"tool_call"}',
      content: bash_content
    )

    rendered = render(partial: "step/bash_commands/bash_command", locals: { bash_command: bash_command })

    assert_includes rendered, "bash-command"
    assert_includes rendered, "prompt"
    assert_includes rendered, "symbol"
    assert_includes rendered, "ls -la"
    assert_includes rendered, "List files with details"
  end

  test "handles bash command without description" do
    run = runs(:one)
    bash_content = "name: Bash\ninputs: {\"command\":\"pwd\"}"

    bash_command = Step::BashCommand.create!(
      run: run,
      raw_response: '{"type":"tool_call"}',
      content: bash_content
    )

    rendered = render(partial: "step/bash_commands/bash_command", locals: { bash_command: bash_command })

    assert_includes rendered, "pwd"
    assert_not_includes rendered, "description"
  end
end
