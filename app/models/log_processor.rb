class LogProcessor
  include DockerStreamProcessor

  ALL = [
    LogProcessor::Text,
    LogProcessor::ClaudeJson,
    LogProcessor::ClaudeStreamingJson
  ].freeze

  def self.process(logs)
    new.process(logs)
  end

  def process(logs)
    raise NotImplementedError, "Subclasses must implement #process"
  end

  def process_container(container, run)
    # Default behavior: wait for container, get logs, process them
    container.wait
    logs = container.logs(stdout: true, stderr: true)
    # Process Docker's binary stream format
    clean_logs = process_docker_stream(logs)

    step_data_list = process(clean_logs)
    step_data_list.each do |step_data|
      run.steps.create!(step_data)
    end
  end
end
