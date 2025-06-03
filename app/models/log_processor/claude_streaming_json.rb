class LogProcessor::ClaudeStreamingJson < LogProcessor
  include LogProcessor::Concerns::ClaudeJsonProcessing

  def process(logs)
    logs.strip.split("\n").filter_map do |line|
      next if line.strip.empty?

      begin
        parsed_item = JSON.parse(line.strip)
        process_item(parsed_item)
      rescue JSON::ParserError
        { raw_response: line, type: "Step::Error", content: line }
      end
    end
  end

  def process_container(container, run)
    Rails.logger.info "Starting attach-based log streaming for run #{run.id}"
    buffer = ""

    # Use attach to get real-time streaming output
    begin
      container.attach(stdout: true, stderr: true, stream: true) do |stream, chunk|
        # Docker attach doesn't add the 8-byte prefix like logs do
        clean_chunk = chunk.force_encoding("UTF-8").scrub
        Rails.logger.info "Received chunk: #{clean_chunk.inspect}"

        buffer += clean_chunk

        # Process complete lines
        while buffer.include?("\n")
          line, buffer = buffer.split("\n", 2)
          process_line(line, run)
        end
      end
    rescue => e
      Rails.logger.error "Attach failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end

    # Process any remaining content in buffer
    if buffer.strip.present?
      Rails.logger.info "Processing remaining buffer: #{buffer.inspect}"
      buffer.split("\n").each do |line|
        process_line(line, run)
      end
    end

    container.wait
    Rails.logger.info "Container finished, streaming complete"
  rescue => e
    Rails.logger.error "Streaming failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    # Fallback to default behavior
    super
  end

  private

  def process_line(line, run)
    return if line.strip.empty?

    Rails.logger.info "Processing line: #{line.inspect}"
    begin
      parsed_item = JSON.parse(line.strip)
      step_data = process_item(parsed_item)
      step = run.steps.create!(step_data)
      Rails.logger.info "Created step: #{step.type}"
      run.broadcast_update
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parse error for line: #{line.inspect} - #{e.message}"
      run.steps.create!(raw_response: line, type: "Step::Error", content: line)
      run.broadcast_update
    rescue => e
      Rails.logger.error "Failed to process streaming step: #{e.message}"
    end
  end
end
