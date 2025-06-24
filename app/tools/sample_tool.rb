# frozen_string_literal: true

class SampleTool < ApplicationTool
  description "Greet someone and show current task ID"

  arguments do
    required(:name).filled(:string).description("Name of the person to greet")
    optional(:prefix).filled(:string).description("Prefix to add to the greeting")
  end

  def call(name:, prefix: "Hello")
    task_id = headers["x-task-id"] || "unknown"
    "#{prefix} #{name}! Current task ID: #{task_id}"
  end
end
