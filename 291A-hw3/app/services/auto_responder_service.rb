# frozen_string_literal: true

# Service that attempts to auto-respond to the first user question in a conversation
# using the assigned expert's FAQ as grounding.
class AutoResponderService
  SKIP_TOKEN = "NO_AUTO_RESPONSE"

  def self.respond_if_applicable(message)
    conversation = message.conversation
    expert = conversation.assigned_expert
    return unless expert

    expert_faq = expert.expert_profile&.expert_faq
    return if expert_faq.blank?

    return unless first_message_from_initiator?(conversation, message)

    llm_reply = generate_reply(expert.username, expert_faq, message.content)
    return if llm_reply.blank?
    return if llm_reply.strip.casecmp(SKIP_TOKEN).zero?

    conversation.messages.create!(
      sender: expert,
      sender_role: "expert",
      content: llm_reply.strip
    )
  rescue => e
    Rails.logger.error("AutoResponderService failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    nil
  end

  def self.first_message_from_initiator?(conversation, message)
    message.sender_id == conversation.initiator_id &&
      conversation.messages.order(:created_at).first&.id == message.id
  end
  private_class_method :first_message_from_initiator?

  def self.generate_reply(expert_username, expert_faq, question)
    client = BedrockClient.new(
      model_id: "anthropic.claude-3-5-haiku-20241022-v1:0"
    )

    system_prompt = <<~PROMPT
      You are assisting on behalf of expert "#{expert_username}".
      You have access to their FAQ. Only answer if the FAQ clearly covers the user's question.
      If you are not confident the FAQ covers it, respond exactly with "#{SKIP_TOKEN}".
      Keep answers short (1-3 sentences).
    PROMPT

    user_prompt = <<~PROMPT
      FAQ:
      #{expert_faq}

      User question:
      #{question}
    PROMPT

    response = client.call(
      system_prompt: system_prompt,
      user_prompt: user_prompt,
      max_tokens: 200,
      temperature: 0.2
    )

    response[:output_text].to_s.strip
  rescue => e
    Rails.logger.error("AutoResponderService LLM failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    nil
  end
  private_class_method :generate_reply
end
