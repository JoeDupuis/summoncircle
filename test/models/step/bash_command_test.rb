require "test_helper"

class Step::BashCommandTest < ActiveSupport::TestCase
  test "should inherit from Step::ToolCall" do
    assert Step::BashCommand < Step::ToolCall
  end

  test "should extract command from content" do
    bash_command = Step::BashCommand.new(
      run: runs(:one),
      raw_response: '{"type":"tool_call"}',
      content: "name: Bash\ninputs: {\"command\":\"ls -la\",\"description\":\"List files\"}"
    )

    assert_equal "ls -la", bash_command.command
  end

  test "should extract description from content" do
    bash_command = Step::BashCommand.new(
      run: runs(:one),
      raw_response: '{"type":"tool_call"}',
      content: "name: Bash\ninputs: {\"command\":\"pwd\",\"description\":\"Show current directory\"}"
    )

    assert_equal "Show current directory", bash_command.description
  end

  test "should handle missing description" do
    bash_command = Step::BashCommand.new(
      run: runs(:one),
      raw_response: '{"type":"tool_call"}',
      content: "name: Bash\ninputs: {\"command\":\"pwd\"}"
    )

    assert_equal "pwd", bash_command.command
    assert_nil bash_command.description
  end

  test "should handle invalid JSON gracefully" do
    bash_command = Step::BashCommand.new(
      run: runs(:one),
      raw_response: '{"type":"tool_call"}',
      content: "name: Bash\ninputs: invalid json"
    )

    assert_nil bash_command.command
    assert_nil bash_command.description
  end

  test "should handle missing inputs line" do
    bash_command = Step::BashCommand.new(
      run: runs(:one),
      raw_response: '{"type":"tool_call"}',
      content: "name: Bash"
    )

    assert_nil bash_command.command
    assert_nil bash_command.description
  end
end
