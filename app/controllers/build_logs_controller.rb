class BuildLogsController < ApplicationController
  include DockerStreamProcessor

  before_action :set_task

  def show
    # If container is already built, try to fetch existing logs
    if @task.container_status.in?([ "running", "exited", "failed" ])
      @existing_logs = fetch_existing_logs
    end
  end

  private

  def set_task
    @task = Task.find(params[:task_id])
  end

  def fetch_existing_logs
    logs = []

    # Try to get container logs if container exists
    if @task.container_id.present?
      begin
        container = Docker::Container.get(@task.container_id)
        container_logs = container.logs(stdout: true, stderr: true, timestamps: true)

        if container_logs.present?
          # Process Docker stream format using the included module
          processed = process_docker_stream(container_logs)
          logs = processed.split("\n").map(&:strip).reject(&:empty?)
        end

        Rails.logger.info "[BuildLogsController] Found #{logs.size} log lines for task #{@task.id}"
      rescue Docker::Error::NotFoundError
        Rails.logger.warn "[BuildLogsController] Container not found for task #{@task.id}"
      rescue => e
        Rails.logger.error "[BuildLogsController] Error fetching logs: #{e.message}"
      end
    end

    logs
  end
end
