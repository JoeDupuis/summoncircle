module DockerTestHelper
  # Create Docker log output with proper binary stream format
  # Docker format: [stream_type(1)][reserved(3)][size(4)][data(size)]
  def docker_log_output(content, stream_type: 1)
    return "" if content.nil?
    
    # Stream type: 1 = stdout, 2 = stderr
    header = [stream_type, 0, 0, 0].pack("C*")  # 4 bytes
    size = [content.bytesize].pack("N")         # 4 bytes big-endian
    header + size + content
  end

  # Mock a Docker container that returns output with proper headers
  def mock_container_with_output(output, status_code: 0)
    container = mock("container")
    container.expects(:start)
    container.expects(:wait).returns({ "StatusCode" => status_code })
    container.expects(:logs).with(stdout: true, stderr: true).returns(docker_log_output(output))
    container.expects(:delete).with(force: true)
    
    # Support for exec calls (used by SSH setup)
    container.expects(:exec).with(anything).at_least(0)
    
    container
  end

  # Mock a simple Docker container with "Success" output
  def mock_container(status_code: 0)
    mock_container_with_output("Success", status_code: status_code)
  end
end