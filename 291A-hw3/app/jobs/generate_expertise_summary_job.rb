# frozen_string_literal: true

# Job to generate an expertise summary for an expert based on their conversation history
class GenerateExpertiseSummaryJob < ApplicationJob
  queue_as :default

  def perform(expert_profile_id)
    expert_profile = ExpertProfile.find(expert_profile_id)
    expert = expert_profile.user

    # Get only the last 50 RESOLVED assignments, ordered by most recent
    assignments = ExpertAssignment.where(expert_id: expert.id, status: "resolved")
                                   .includes(conversation: [:messages, :initiator])
                                   .order(resolved_at: :desc)
                                   .limit(50)

    return if assignments.empty?

    # Build context from conversations
    conversation_data = assignments.map do |assignment|
      conversation = assignment.conversation
      messages = conversation.messages.order(created_at: :asc)

      {
        title: conversation.title,
        status: assignment.status,
        messages: messages.map { |m| "#{m.sender_role}: #{m.content}" }.join("\n")
      }
    end

    # Generate summary using LLM
    summary = ExpertiseSummaryService.generate_summary(expert, conversation_data)

    # Update expert profile
    expert_profile.update!(expertise_summary: summary)
  end
end
