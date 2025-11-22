class Message < ApplicationRecord
  # Associations
  belongs_to :conversation
  belongs_to :sender, class_name: "User", foreign_key: "sender_id"

  # Validations
  validates :content, presence: true
  validates :sender_role, presence: true, inclusion: { in: %w[initiator expert] }

  # Callbacks
  after_create :update_conversation_last_message_at

  private

  def update_conversation_last_message_at
    # Update both last_message_at and updated_at (via touch) to trigger polling updates
    conversation.update_columns(last_message_at: created_at, updated_at: Time.current)
  end
end
