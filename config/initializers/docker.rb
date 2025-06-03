require "docker"

Docker.options = {
  read_timeout: 600,
  write_timeout: 600,
  connect_timeout: 60
}
