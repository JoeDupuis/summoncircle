class AddCostTrackingToSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :steps, :cost_usd, :decimal, precision: 10, scale: 8
    add_column :steps, :input_tokens, :integer
    add_column :steps, :output_tokens, :integer
    add_column :steps, :cache_creation_tokens, :integer
    add_column :steps, :cache_read_tokens, :integer
  end
end
