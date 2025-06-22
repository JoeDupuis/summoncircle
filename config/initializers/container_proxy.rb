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
    host = env["HTTP_HOST"] || ""
    host.match?(/^task-\d+\./)
  end

  def handle_proxy_request(env)
    request = Rack::Request.new(env)
    host = env["HTTP_HOST"] || ""
    
    if (match = host.match(/^task-(\d+)\./))
      task_id = match[1]
      path = env["PATH_INFO"] || "/"
      
      task = Task.find_by(id: task_id)
      
      if task && task.container_id.present?
        begin
          container = Docker::Container.get(task.container_id)
          container_info = container.json
          
          if ENV["CONTAINER_PROXY_TARGET_CONTAINERS"].present?
            # Proxy directly to container's internal IP and port
            host = container_info["NetworkSettings"]["IPAddress"]
            port = task.project.dev_container_port
          else
            # Proxy to localhost and the mapped host port (default)
            host = "localhost"
            port = nil
            
            if task.project.dev_container_port.present?
              port_mapping = container_info["NetworkSettings"]["Ports"]["#{task.project.dev_container_port}/tcp"]
              if port_mapping && port_mapping.first
                port = port_mapping.first["HostPort"]
              end
            end
          end
          
          if host.present? && port.present?
            # Update the host for the proxy but keep the original path
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
      [ 404, { "Content-Type" => "text/plain" }, [ "Invalid subdomain" ] ]
    end
  rescue => e
    Rails.logger.error "Container proxy error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    [ 500, { "Content-Type" => "text/plain" }, [ "Proxy error: #{e.message}" ] ]
  end
end

Rails.application.config.middleware.use ContainerProxy unless Rails.env.test?