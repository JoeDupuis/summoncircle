namespace :volumes do
  desc "Flush all existing Docker volumes with summoncircle prefix"
  task flush: :environment do
    require "docker"

    begin
      volumes = Docker::Volume.all
      summoncircle_volumes = volumes.select { |volume| volume.info["Name"].start_with?("summoncircle_") }

      if summoncircle_volumes.empty?
        puts "No summoncircle volumes found."
        next
      end

      puts "Found #{summoncircle_volumes.size} summoncircle volumes:"
      summoncircle_volumes.each { |volume| puts "  - #{volume.info["Name"]}" }

      print "Are you sure you want to delete these volumes? (y/N): "
      confirmation = $stdin.gets.chomp.downcase

      if confirmation == "y" || confirmation == "yes"
        summoncircle_volumes.each do |volume|
          begin
            volume.delete
            puts "Deleted: #{volume.info["Name"]}"
          rescue Docker::Error::ConflictError
            puts "Volume in use, forcing deletion: #{volume.info["Name"]}"
            volume.delete(force: true)
          rescue => e
            puts "Failed to delete #{volume.info["Name"]}: #{e.message}"
          end
        end
        puts "Volume flush complete."
      else
        puts "Volume flush cancelled."
      end
    rescue => e
      puts "Error accessing Docker: #{e.message}"
      puts "Make sure Docker is running and accessible."
    end
  end
end
