require "test_helper"

class DockerContainerBuilderTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:one)
    @builder = DockerContainerBuilder.new(@task)
  end

  test "stream_build_log broadcasts Docker build events" do
    build_event = { "stream" => "Step 1/5 : FROM ruby:3.0\n" }.to_json

    Turbo::StreamsChannel.expects(:broadcast_append_to).with(
      "task_#{@task.id}_build_logs",
      target: "build-logs",
      html: "<div class='log-entry info'>Step 1/5 : FROM ruby:3.0</div>"
    )

    @builder.send(:stream_build_log, build_event)
  end

  test "stream_build_log handles error events" do
    error_event = { "error" => "Cannot connect to Docker daemon" }.to_json

    Turbo::StreamsChannel.expects(:broadcast_append_to).with(
      "task_#{@task.id}_build_logs",
      target: "build-logs",
      html: "<div class='log-entry error'>ERROR: Cannot connect to Docker daemon</div>"
    )

    @builder.send(:stream_build_log, error_event)
  end

  test "stream_build_log applies correct CSS classes" do
    test_cases = [
      [ { "stream" => "ERROR: Build failed\n" }.to_json, "error", "ERROR: Build failed" ],
      [ { "stream" => "WARNING: Deprecated command\n" }.to_json, "warning", "WARNING: Deprecated command" ],
      [ { "stream" => "Step 2/5 : RUN bundle install\n" }.to_json, "info", "Step 2/5 : RUN bundle install" ],
      [ { "stream" => "---> Using cache\n" }.to_json, "info", "---&gt; Using cache" ],
      [ { "stream" => "Successfully built abcd1234\n" }.to_json, "success", "Successfully built abcd1234" ],
      [ { "stream" => "Build complete!\n" }.to_json, "success", "Build complete!" ],
      [ { "stream" => "Regular output\n" }.to_json, "", "Regular output" ]
    ]

    test_cases.each do |event_json, expected_class, expected_text|
      css_class = expected_class.empty? ? " " : " #{expected_class}"
      Turbo::StreamsChannel.expects(:broadcast_append_to).with(
        "task_#{@task.id}_build_logs",
        target: "build-logs",
        html: "<div class='log-entry#{css_class}'>#{expected_text}</div>"
      )
      @builder.send(:stream_build_log, event_json)
    end
  end

  test "stream_build_log ignores empty streams" do
    empty_event = { "stream" => "\n" }.to_json

    # Should not broadcast anything for empty streams
    Turbo::StreamsChannel.expects(:broadcast_append_to).never

    @builder.send(:stream_build_log, empty_event)
  end

  test "stream_build_log handles malformed JSON" do
    malformed_json = "not valid json"

    Turbo::StreamsChannel.expects(:broadcast_append_to).with(
      "task_#{@task.id}_build_logs",
      target: "build-logs",
      html: "<div class='log-entry '>not valid json</div>"
    )

    @builder.send(:stream_build_log, malformed_json)
  end
end
