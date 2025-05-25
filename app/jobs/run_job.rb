class RunJob < ApplicationJob
  queue_as :default

  def perform(run_id)
    run = Run.find(run_id)
    agent = run.task.agent

    run.update!(status: "running", started_at: Time.current)

    begin
      # Build command array based on whether this is initial or continue
      command_template = run.is_initial ? agent.start_arguments : agent.continue_arguments
      command = command_template.map do |arg|
        arg.gsub("{PROMPT}", run.prompt)
      end

      # Create and run the container
      container = Docker::Container.create(
        "Image" => agent.docker_image,
        "Cmd" => command,
        "WorkingDir" => "/workspace",
        "HostConfig" => {
          "Binds" => [ "task_#{run.task_id}_volume:/workspace" ]
        }
      )

      # Start the container and capture output
      container.start

      # Wait for container to finish
      container.wait

      # Get logs after container has finished
      raw_output = container.logs(stdout: true, stderr: true)

      # Parse Docker logs (remove 8-byte header from each log entry)
      output = parse_docker_logs(raw_output)

      # Update run with output and status
      run.update!(
        output: output,
        status: "completed",
        completed_at: Time.current
      )
    rescue => e
      # Handle errors
      run.update!(
        output: "Error: #{e.message}",
        status: "failed",
        completed_at: Time.current
      )
    ensure
      # Clean up container
      container&.delete(force: true) if defined?(container)
    end
  end

  private

  def parse_docker_logs(raw_logs)
    return "" if raw_logs.nil? || raw_logs.empty?

    parsed = []
    offset = 0

    while offset < raw_logs.length
      # Docker log format: 8-byte header + content
      # Header: 1 byte stream type, 3 bytes padding, 4 bytes size (big-endian)
      break if offset + 8 > raw_logs.length

      header = raw_logs[offset..offset+7]
      size = header[4..7].unpack("N")[0]  # N = 32-bit unsigned, network byte order

      break if offset + 8 + size > raw_logs.length

      content = raw_logs[offset+8..offset+8+size-1]
      parsed << content.force_encoding("UTF-8")

      offset += 8 + size
    end

    parsed.join
  end
end
