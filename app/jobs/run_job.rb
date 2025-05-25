class RunJob < ApplicationJob
  queue_as :default

  def perform(run_id)
    run = Run.find(run_id)
    agent = run.task.agent

    run.update!(status: :running, started_at: Time.current)

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
      output = container.logs(stdout: true, stderr: true)

      # Update run with output and status
      run.update!(
        output: output,
        status: :completed,
        completed_at: Time.current
      )
    rescue => e
      # Handle errors
      run.update!(
        output: "Error: #{e.message}",
        status: :failed,
        completed_at: Time.current
      )
    ensure
      # Clean up container
      container&.delete(force: true) if defined?(container)
    end
  end
end
