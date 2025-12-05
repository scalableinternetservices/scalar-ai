# frozen_string_literal: true

# Service to generate expertise summaries for experts based on their conversation history
class ExpertiseSummaryService
  def self.generate_summary(expert, conversation_data)
    return "" if conversation_data.empty?

    meaningful_conversations = conversation_data.select do |conv|
      conv[:messages].present?
      # FIXME: Can filter out conversations with no messages for better quality and reduced context size
      # conv[:messages].present? && conv[:messages].length > 2
    end

    # If no meaningful conversations, return a default summary
    if meaningful_conversations.empty?
      return "No expertise areas"
    end

    # Build context for the LLM
    context = meaningful_conversations.map.with_index do |conv, idx|
      <<~CONV
        Conversation #{idx + 1}: #{conv[:title]}
        Messages:
        #{conv[:messages]}
      CONV
    end.join("\n---\n")

    system_prompt = <<~PROMPT
      You are an AI assistant that analyzes an expert's conversation history to generate a concise expertise summary.
      
      Your task is to:
      1. Identify the main topics and areas where the expert has helped users
      2. Note the types of questions they typically answer
      3. Highlight any specializations or patterns in their expertise
      4. Keep the summary concise (2-3 sentences maximum)
      5. Be specific about technical domains, technologies, or problem types
      
      Focus on technical domains, problem types, and expertise areas, not on communication style.
      If the conversation history is very limited, note that the expert is new but mention any visible patterns.
    PROMPT

    user_prompt = <<~PROMPT
      Analyze the following conversation history for expert "#{expert.username}" and generate a brief expertise summary:

      #{context}

      Generate a concise 2-3 sentence summary of this expert's areas of expertise based on the conversations above.
      Be specific about the types of problems they help with.
    PROMPT

    client = BedrockClient.new(
      model_id: "anthropic.claude-3-5-haiku-20241022-v1:0"
    )

    response = client.call(
      system_prompt: system_prompt,
      user_prompt: user_prompt,
      max_tokens: 250,
      temperature: 0.3
    )

    summary = response[:output_text].strip
    
    # If LLM returns empty or very short response, use default
    if summary.length < 20
      "No expertise areas"
    else
      summary
    end
  rescue => e
    Rails.logger.error("Failed to generate expertise summary: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    ""
  end
end
