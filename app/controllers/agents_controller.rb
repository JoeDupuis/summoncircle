class AgentsController < ApplicationController
  before_action :set_agent, only: %i[show edit update destroy]

  def index
    @agents = Agent.kept
  end

  def show
  end

  def new
    @agent = Agent.new

    if params[:source_id].present?
      source_agent = Agent.find(params[:source_id])
      @agent = source_agent.dup
      @agent.name = "Copy of #{source_agent.name}"

      @agent.volumes_config = source_agent.volumes_config

      if source_agent.agent_specific_settings.any?
        source_setting = source_agent.agent_specific_settings.first
        @agent.agent_specific_setting_type = source_setting.type
        @agent.agent_specific_settings.build(type: source_setting.type)
      end
    end
  end

  def create
    @agent = Agent.new(agent_params.except(:volumes_config))
    if @agent.save
      create_volumes_from_config(@agent, params[:agent][:volumes_config])
      redirect_to @agent, notice: "Agent was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @agent.update(agent_params.except(:volumes_config))
      volumes_config = params[:agent][:volumes_config]
      # Only update volumes if volumes_config is present and different from current
      if volumes_config.present? && volumes_config != @agent.volumes_config
        @agent.volumes.destroy_all
        create_volumes_from_config(@agent, volumes_config)
      end

      update_agent_secrets if params[:agent][:secrets].present?

      redirect_to @agent, notice: "Agent was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @agent.discard
    redirect_to agents_url, notice: "Agent was successfully archived."
  end

  private
    def set_agent
      @agent = Agent.find(params[:id])
    end

    def agent_params
      params.require(:agent)
            .permit(:name, :docker_image, :workplace_path, :start_arguments, :continue_arguments, :volumes_config, :env_variables_json, :log_processor, :user_id, :instructions_mount_path, :ssh_mount_path, :home_path, :mcp_sse_endpoint, :agent_specific_setting_type,
                    agent_specific_settings_attributes: [ :id, :type, :_destroy ])
    end

    def create_volumes_from_config(agent, volumes_config)
      return unless volumes_config.present?

      volumes_data = JSON.parse(volumes_config)
      volumes_data.each do |volume_name, config|
        if config.is_a?(Hash)
          agent.volumes.create!(
            name: volume_name,
            path: config["path"],
            external: config["external"] == true,
            external_name: config["external_name"]
          )
        else
          agent.volumes.create!(name: volume_name, path: config)
        end
      end
    rescue JSON::ParserError
      Rails.logger.error "Invalid JSON in volumes_config"
    end

    def update_agent_secrets
      secrets_json = params[:agent][:secrets]
      return if secrets_json.blank?

      begin
        secrets_hash = JSON.parse(secrets_json)
        @agent.update_secrets(secrets_hash)
      rescue JSON::ParserError
        flash[:alert] = "Invalid JSON format for secrets"
      end
    end
end
