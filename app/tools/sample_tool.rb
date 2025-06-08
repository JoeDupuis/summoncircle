# frozen_string_literal: true

class SampleTool < ApplicationTool
  description "Greet someone"

  arguments do
    required(:name).filled(:string).description("Name of the person to greet")
    optional(:prefix).filled(:string).description("Prefix to add to the greeting")
  end

  def call(name:, prefix: "Hello")
    "#{prefix} #{name}!"
  end
end
