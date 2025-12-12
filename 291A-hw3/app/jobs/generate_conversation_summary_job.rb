class GenerateConversationSummaryJob < ApplicationJob
    queue_as :default
  
    def perform(conversation_id)
      conversation = Conversation.find_by(id: conversation_id)
      return unless conversation
  
      summary_service = ConversationSummaryService.new(conversation)
      summary = summary_service.generate_summary
  
      conversation.update_column(:summary, summary) if summary
    end
  end