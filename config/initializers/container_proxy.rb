require "rack-proxy"

class ContainerProxy
  def initialize(app)
    @app = app
    @proxy = Rack::Proxy.new(streaming: false)
  end

  def call(env)
    if proxy_request?(env)
      handle_proxy_request(env)
    else
      @app.call(env)
    end
  end

  private

  def proxy_request?(env)
    env["PATH_INFO"].start_with?("/tasks/") && env["PATH_INFO"].include?("/proxy")
  end

  def handle_proxy_request(env)
    request = Rack::Request.new(env)
    
    if (match = request.path.match(%r{^/tasks/(\d+)/proxy(/.*)?$}))
      task_id = match[1]
      path = match[2] || "/"
      
      task = Task.find_by(id: task_id)
      
      if task && task.container_id.present?
        begin
          container = Docker::Container.get(task.container_id)
          container_info = container.json
          
          if ENV["CONTAINER_PROXY_MODE"].present?
            host = container_info["NetworkSettings"]["IPAddress"]
          else
            host = "localhost"
          end
          
          port = task.project.dev_container_port
          
          if host.present? && port.present?
            # Rewrite the request for the proxy
            env["PATH_INFO"] = path
            env["REQUEST_PATH"] = path
            env["REQUEST_URI"] = "http://#{host}:#{port}#{path}"
            env["HTTP_HOST"] = "#{host}:#{port}"
            env["SERVER_NAME"] = host
            env["SERVER_PORT"] = port.to_s
            
            # Create a new proxy instance with the backend
            proxy = Rack::Proxy.new(backend: "http://#{host}:#{port}", streaming: false)
            proxy.call(env)
          else
            [ 503, { "Content-Type" => "text/plain" }, [ "Container not accessible" ] ]
          end
        rescue Docker::Error::NotFoundError
          [ 404, { "Content-Type" => "text/plain" }, [ "Container not found" ] ]
        end
      else
        [ 404, { "Content-Type" => "text/plain" }, [ "Task or container not found" ] ]
      end
    else
      [ 404, { "Content-Type" => "text/plain" }, [ "Invalid proxy path" ] ]
    end
  rescue => e
    Rails.logger.error "Container proxy error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    [ 500, { "Content-Type" => "text/plain" }, [ "Proxy error: #{e.message}" ] ]
  end
end

Rails.application.config.middleware.use ContainerProxy unless Rails.env.test?