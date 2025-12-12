class ConversationSummaryService
    def initialize(conversation)
      @conversation = conversation
      @bedrock_client = BedrockClient.new(
        model_id: "anthropic.claude-3-5-haiku-20241022-v1:0"
      )
    end
  
    def generate_summary
      return nil if @conversation.messages.empty?
  
      messages_text = build_messages_context
      
      system_prompt = "You are a helpful assistant that creates brief summaries of conversations. " \
                      "Provide a concise one-sentence summary (max 100 characters) of the main topic or question."
      
      user_prompt = "Summarize this conversation:\n\n#{messages_text}"
  
      response = @bedrock_client.call(
        system_prompt: system_prompt,
        user_prompt: user_prompt,
        max_tokens: 700,
        temperature: 0.2
      )
  
      # Truncate to ensure it fits in UI
      response[:output_text].strip[0..150]
    rescue => e
      Rails.logger.error("Failed to generate summary: #{e.message}")
      # Fallback to title if summary generation fails
      @conversation.title[0..150]
    end
  
    private
  
    def build_messages_context
      @conversation.messages
                   .order(created_at: :asc)
                   .limit(10) # Only use first 5 messages to keep context small
                   .map { |m| "#{m.sender.username}: #{m.content}" }
                   .join("\n")
    end
  end