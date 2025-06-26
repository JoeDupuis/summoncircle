require "test_helper"

class UserSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @agent = agents(:one)
    login @user
  end

  test "should unset auto task naming agent when selecting none" do
    @user.update!(auto_task_naming_agent: @agent)

    patch user_settings_path, params: { user: { auto_task_naming_agent_id: "" } }

    assert_redirected_to user_settings_path
    assert_nil @user.reload.auto_task_naming_agent_id
  end

  test "should set auto task naming agent when selecting an agent" do
    patch user_settings_path, params: { user: { auto_task_naming_agent_id: @agent.id } }

    assert_redirected_to user_settings_path
    assert_equal @agent.id, @user.reload.auto_task_naming_agent_id
  end
end
