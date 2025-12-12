class Message < ApplicationRecord
  # Associations
  belongs_to :conversation
  belongs_to :sender, class_name: "User", foreign_key: "sender_id"

  # Validations
  validates :content, presence: true
  validates :sender_role, presence: true, inclusion: { in: %w[initiator expert] }

  # Callbacks
  after_create :update_conversation_last_message_at
  after_create :enqueue_expert_assignment, if: :first_message?
  after_create :enqueue_summary_generation, if: :should_regenerate_summary?

  private

  def update_conversation_last_message_at
    # Update both last_message_at and updated_at (via touch) to trigger polling updates
    conversation.update_columns(last_message_at: created_at, updated_at: Time.current)
  end

  def first_message?
    # Check if this is the first message in the conversation from the initiator
    sender_role == "initiator" && conversation.messages.count == 1
  end

  def enqueue_expert_assignment
    # Only trigger auto-assignment if conversation is not already assigned
    return if conversation.assigned_expert_id.present?

    AssignExpertJob.perform_later(conversation.id)
  end

  def should_regenerate_summary?
    # Regenerate summary after first message and every 3 messages
    message_count = conversation.messages.count
    message_count == 1 || message_count % 3 == 0
  end

  def enqueue_summary_generation
    GenerateConversationSummaryJob.perform_later(conversation.id)
  end
end
