class AddDockerContainerSupport < ActiveRecord::Migration[8.0]
  def change
    # Add Docker container info to tasks
    add_column :tasks, :container_id, :string
    add_column :tasks, :container_name, :string
    add_column :tasks, :container_status, :string
    add_column :tasks, :docker_image_id, :string
    add_column :tasks, :container_host_port, :integer

    # Add Docker support to projects
    add_column :projects, :dev_dockerfile_path, :text
    add_column :projects, :dev_container_port, :integer, default: 3000
  end
end
