# Configure global Docker URL if DOCKER_HOST environment variable is set
if ENV["DOCKER_HOST"].present?
  Docker.url = ENV["DOCKER_HOST"]
  Docker.options = {
    read_timeout: 600,
    write_timeout: 600,
    connect_timeout: 60
  }
end
