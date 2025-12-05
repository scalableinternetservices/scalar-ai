# frozen_string_literal: true

# Job to auto-assign a conversation to the best expert based on their expertise summaries
class AutoAssignConversationJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)

    # Don't auto-assign if already assigned
    return if conversation.assigned_expert_id.present?

    # Get all expert profiles with summaries
    experts = ExpertProfile.where.not(expertise_summary: nil)
                          .where.not(expertise_summary: "")
                          .includes(:user)

    # If no experts have summaries, leave unassigned
    return if experts.empty?

    # Get the first message content if available
    first_message = conversation.messages.order(created_at: :asc).first&.content || ""

    # Use LLM to select best expert
    selected_expert = ExpertAssignmentService.select_best_expert(
      conversation_title: conversation.title,
      conversation_content: first_message,
      experts: experts
    )

    # Assign if an expert was selected
    if selected_expert
      conversation.update!(
        assigned_expert_id: selected_expert.user_id,
        status: "active"
      )

      # Create expert assignment record
      ExpertAssignment.create!(
        conversation: conversation,
        expert_id: selected_expert.user_id,
        status: "active"
      )
    end
  end
end
