class LogProcessor
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
    # Docker logs prefix each line with 8 bytes of metadata that we need to strip
    clean_logs = logs.force_encoding("UTF-8").scrub.lines.map { |line| line[8..] || "" }.join.strip

    step_data_list = process(clean_logs)
    step_data_list.each do |step_data|
      run.steps.create!(step_data)
    end
  end
end
