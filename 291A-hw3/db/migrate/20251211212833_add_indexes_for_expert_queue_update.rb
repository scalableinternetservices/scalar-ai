class AddIndexesForExpertQueueUpdate < ActiveRecord::Migration[8.1]
  def change
    add_index :conversations, [:status, :updated_at]
    add_index :conversations, [:assigned_expert_id, :status, :updated_at]
  end
end
