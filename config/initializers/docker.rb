# Configure global Docker URL if DOCKER_URL environment variable is set
if ENV["DOCKER_URL"].present?
  Docker.url = ENV["DOCKER_URL"]
  Docker.options = {
    read_timeout: 600,
    write_timeout: 600,
    connect_timeout: 60
  }
end
