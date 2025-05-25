Rails.application.configure do
  MissionControl::Jobs.base_controller_class = "MissionControl::Jobs::ApplicationController"
end
