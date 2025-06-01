class AgentsController < ApplicationController
  before_action :set_agent, only: %i[show edit update destroy]

  def index
    @agents = Agent.kept
  end

  def show
  end

  def new
    @agent = Agent.new
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
            .permit(:name, :docker_image, :docker_host, :workplace_path, :start_arguments, :continue_arguments, :volumes_config, :env_variables_json, :log_processor, :user_id, :instructions_mount_path)
    end

    def create_volumes_from_config(agent, volumes_config)
      return unless volumes_config.present?

      volumes_data = JSON.parse(volumes_config)
      volumes_data.each do |volume_name, path|
        agent.volumes.create!(name: volume_name, path: path)
      end
    rescue JSON::ParserError
      Rails.logger.error "Invalid JSON in volumes_config"
    end
end
