namespace :claude_oauth do
  desc "Build the Claude OAuth Docker image"
  task build_image: :environment do
    puts "Building Claude OAuth Docker image..."

    oauth_repo_path = Rails.root.join("..", "..", "..", "claude_oauth")

    unless File.exist?(oauth_repo_path.join("Dockerfile"))
      puts "Error: claude_oauth repository not found at #{oauth_repo_path}"
      puts "Please clone https://github.com/JoeDupuis/claude_oauth to ~/workspace/claude_oauth"
      exit 1
    end

    Dir.chdir(oauth_repo_path) do
      system("docker build -t claude_oauth:latest .", exception: true)
    end

    puts "Claude OAuth Docker image built successfully!"
  end

  desc "Create claude_config Docker volume"
  task create_volume: :environment do
    puts "Creating claude_config Docker volume..."

    begin
      Docker::Volume.create("claude_config")
      puts "Docker volume 'claude_config' created successfully!"
    rescue Docker::Error::ConflictError
      puts "Docker volume 'claude_config' already exists."
    end
  end

  desc "Setup Claude OAuth (build image and create volume)"
  task setup: [ :build_image, :create_volume ] do
    puts "Claude OAuth setup complete!"
  end
end
