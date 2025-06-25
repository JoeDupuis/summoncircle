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

      source_agent.volumes.each do |volume|
        @agent.volumes.build(volume.attributes.except("id", "agent_id", "created_at", "updated_at"))
      end

      if source_agent.agent_specific_settings.any?
        source_setting = source_agent.agent_specific_settings.first
        @agent.agent_specific_setting_type = source_setting.type
        @agent.agent_specific_settings.build(type: source_setting.type)
      end
    end
  end

  def create
    @agent = Agent.new(agent_params)
    if @agent.save
      redirect_to @agent, notice: "Agent was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @agent.update(agent_params)
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
            .permit(:name, :docker_image, :workplace_path, :start_arguments, :continue_arguments, :env_variables_json, :log_processor, :user_id, :instructions_mount_path, :ssh_mount_path, :home_path, :mcp_sse_endpoint, :agent_specific_setting_type,
                    agent_specific_settings_attributes: [ :id, :type, :_destroy ],
                    env_variables_attributes: [ :id, :key, :value, :_destroy ],
                    secrets_attributes: [ :id, :key, :value, :_destroy ],
                    volumes_attributes: [ :id, :name, :path, :external, :external_name, :_destroy ])
    end
end
