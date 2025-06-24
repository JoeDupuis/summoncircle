class AutoTaskNamingJob < ApplicationJob
  queue_as :default

  def perform(task, prompt)
    Rails.logger.info "AutoTaskNamingJob starting for task #{task.id}"
    return unless task.user.auto_task_naming_agent

    naming_prompt = build_naming_prompt(prompt)
    naming_agent = task.user.auto_task_naming_agent
    Rails.logger.info "Using naming agent: #{naming_agent.name} (#{naming_agent.id})"

    temp_task = create_temporary_naming_task(task, naming_agent)

    run = temp_task.runs.build(prompt: naming_prompt)
    run.skip_agent = true
    run.save!

    begin
      run.execute!
      generated_name = extract_name_from_run(run)

      if generated_name.present?
        task.update!(description: generated_name.strip)
      end
    rescue => e
      Rails.logger.error "Auto task naming failed: #{e.message}"
    ensure
      temp_task.destroy
    end
  end

  private

  def build_naming_prompt(original_prompt)
    "I need a name for a task. Keep it short, but multiple words and spaces are allowed. It needs to describe the prompt. Answer with the name but nothing else. Your answer will be set as the name automatically. Here's the prompt: #{original_prompt}"
  end

  def create_temporary_naming_task(original_task, naming_agent)
    Task.create!(
      project: original_task.project,
      agent: naming_agent,
      user: original_task.user,
      description: "temp-naming-task-#{Time.current.to_i}"
    )
  end

  def extract_name_from_run(run)
    text_steps = run.steps.where(type: "Step::Text")
    return nil if text_steps.empty?

    text_steps.last.content
  end
end
