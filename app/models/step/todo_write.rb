class Step::TodoWrite < Step::ToolCall
  def todos
    todos_data = tool_input.dig("todos") || []
    todos_data.map do |todo|
      OpenStruct.new(
        id: todo["id"],
        content: todo["content"],
        status: todo["status"],
        priority: todo["priority"]
      )
    end
  end

  def pending_todos
    todos.select { |t| t.status == "pending" }
  end

  def in_progress_todos
    todos.select { |t| t.status == "in_progress" }
  end

  def completed_todos
    todos.select { |t| t.status == "completed" }
  end

  def total_count
    todos.count
  end

  def completed_count
    completed_todos.count
  end

  def progress_percentage
    return 0 if total_count.zero?
    (completed_count.to_f / total_count * 100).round
  end
end