module DockerStreamProcessor
  extend ActiveSupport::Concern

  private

  def process_docker_stream(raw_logs)
    return "" if raw_logs.nil? || raw_logs.empty?

    # Force to binary encoding to handle the stream properly
    logs = raw_logs.dup.force_encoding(Encoding::ASCII_8BIT)
    output = []
    offset = 0

    while offset < logs.bytesize
      # Need at least 8 bytes for the header
      break if offset + 8 > logs.bytesize

      # Read the 8-byte header
      # Format: stream_type(1) + reserved(3) + size(4)
      header = logs.byteslice(offset, 8)
      stream_type = header.getbyte(0)
      size = header.byteslice(4, 4).unpack1("N") # big-endian 32-bit

      # Move past the header
      offset += 8

      # Read the data chunk
      break if offset + size > logs.bytesize
      chunk = logs.byteslice(offset, size)

      # Add to output if it's stdout (stream_type 1) or stderr (stream_type 2)
      if stream_type == 1 || stream_type == 2
        output << chunk.force_encoding("UTF-8").scrub
      end

      # Move to next chunk
      offset += size
    end

    output.join.strip
  end
end
