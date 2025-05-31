class AddStepTypeAndContentToSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :steps, :type, :string
    add_column :steps, :content, :text
  end
end
