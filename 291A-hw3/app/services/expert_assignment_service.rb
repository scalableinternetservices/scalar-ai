# frozen_string_literal: true

# Service to auto-assign conversations to the best expert based on expertise summaries
class ExpertAssignmentService
  def self.select_best_expert(conversation_title:, conversation_content:, experts:)
    return nil if experts.empty?

    # Build expert profiles for LLM
    expert_profiles = experts.map.with_index do |expert_profile, idx|
      <<~PROFILE
        Expert #{idx + 1}: #{expert_profile.user.username}
        Expertise Summary: #{expert_profile.expertise_summary}
      PROFILE
    end.join("\n")

    system_prompt = <<~PROMPT
      You are an AI assistant that assigns customer support conversations to the most appropriate expert.
      
      Your task is to:
      1. Analyze the conversation title and initial content
      2. Review the expertise summaries of available experts
      3. Select the best-matching expert OR determine if no expert is appropriate
      4. Respond with ONLY the expert number (e.g., "1", "2", "3") or "NONE" if no expert is suitable
      
      Be conservative - only assign if there's a clear match. If the question is too vague or doesn't match any expertise, respond with "NONE".
    PROMPT

    user_prompt = <<~PROMPT
      New conversation to assign:
      Title: #{conversation_title}
      Initial Content: #{conversation_content.present? ? conversation_content : "No initial message"}

      Available experts:
      #{expert_profiles}

      Which expert should handle this conversation? Respond with ONLY the expert number (1, 2, 3, etc.) or "NONE" if no expert is appropriate.
    PROMPT

    client = BedrockClient.new(
      model_id: "anthropic.claude-3-5-haiku-20241022-v1:0"
    )

    response = client.call(
      system_prompt: system_prompt,
      user_prompt: user_prompt,
      max_tokens: 10,
      temperature: 0.1
    )

    # Parse the response
    answer = response[:output_text].strip.upcase

    if answer == "NONE" || answer.empty?
      nil
    elsif answer.match?(/^\d+$/)
      expert_index = answer.to_i - 1
      experts[expert_index] if expert_index >= 0 && expert_index < experts.length
    else
      # Try to extract a number from the response
      number = answer.scan(/\d+/).first&.to_i
      if number && number > 0 && number <= experts.length
        experts[number - 1]
      else
        nil
      end
    end
  rescue => e
    Rails.logger.error("Failed to auto-assign conversation: #{e.message}")
    nil
  end
end
