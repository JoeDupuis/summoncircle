# frozen_string_literal: true

class RenameTaskTool < ApplicationTool
  description "Rename a task's description"

  arguments do
    required(:new_name).filled(:string).description("New name/description for the task")
  end

  def call(new_name:)
    task_id = headers["x-task-id"]

    if task_id.blank?
      return "Error: No task ID provided in headers"
    end

    task = Task.find_by(id: task_id)

    if task.nil?
      return "Error: Task with ID #{task_id} not found"
    end

    old_name = task.description
    task.update!(description: new_name)

    "Successfully renamed task from '#{old_name}' to '#{new_name}'"
  end
end
