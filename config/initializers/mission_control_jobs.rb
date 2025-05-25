Rails.application.configure do
  MissionControl::Jobs.base_controller_class = "AdminController"
end
