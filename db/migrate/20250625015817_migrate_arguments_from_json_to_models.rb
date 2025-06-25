class MigrateArgumentsFromJsonToModels < ActiveRecord::Migration[8.0]
  def up
    Agent.find_each do |agent|
      if agent.start_arguments.present?
        agent.start_arguments.each_with_index do |arg, index|
          agent.start_arguments_records.create!(value: arg, position: index)
        end
      end

      if agent.continue_arguments.present?
        agent.continue_arguments.each_with_index do |arg, index|
          agent.continue_arguments_records.create!(value: arg, position: index)
        end
      end
    end
  end

  def down
    Agent.find_each do |agent|
      agent.update!(
        start_arguments: agent.start_arguments_records.order(:position).pluck(:value),
        continue_arguments: agent.continue_arguments_records.order(:position).pluck(:value)
      )
    end

    StartArgument.destroy_all
    ContinueArgument.destroy_all
  end
end
