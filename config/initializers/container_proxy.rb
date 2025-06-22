require "rack-proxy"

class ContainerProxy < Rack::Proxy
  def initialize(app = nil, opts = {})
    @app = app
    super(opts.merge(backend: "http://localhost", streaming: false))
  end

  def call(env)
    if proxy_request?(env)
      perform_request(env)
    else
      @app.call(env) if @app
    end
  end

  def perform_request(env)
    request = Rack::Request.new(env)

    if (match = request.path.match(%r{^/tasks/(\d+)/proxy(/.*)?$}))
      task_id = match[1]
      path = match[2] || "/"

      task = Task.find_by(id: task_id)

      if task && task.container_id.present?
        container = Docker::Container.get(task.container_id)
        container_info = container.json

        if ENV["CONTAINER_PROXY_MODE"].present?
          host = container_info["NetworkSettings"]["IPAddress"]
        else
          host = "localhost"
        end

        port = task.project.dev_container_port

        if host.present? && port.present?
          env["PATH_INFO"] = path
          env["REQUEST_PATH"] = path
          env["REQUEST_URI"] = path

          @backend = URI("http://#{host}:#{port}")
          @streaming = false

          super(env)
        else
          [ 503, { "Content-Type" => "text/plain" }, [ "Container not accessible" ] ]
        end
      else
        [ 404, { "Content-Type" => "text/plain" }, [ "Task or container not found" ] ]
      end
    else
      @app.call(env)
    end
  rescue Docker::Error::NotFoundError
    [ 404, { "Content-Type" => "text/plain" }, [ "Container not found" ] ]
  rescue => e
    Rails.logger.error "Container proxy error: #{e.message}"
    [ 500, { "Content-Type" => "text/plain" }, [ "Proxy error" ] ]
  end

  def proxy_request?(env)
    env["PATH_INFO"].start_with?("/tasks/") && env["PATH_INFO"].include?("/proxy")
  end

  def rewrite_env(env)
    env
  end
end

Rails.application.config.middleware.use ContainerProxy unless Rails.env.test?
