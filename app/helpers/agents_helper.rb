module AgentsHelper
  def agent_type_options(current_setting)
    available_settings = AgentSpecificSetting.available_types
    options = [ [ "None", "" ] ] + available_settings.map { |s| [ s[:display_name], s[:type] ] }
    options_for_select(options, current_setting&.type)
  end
end
