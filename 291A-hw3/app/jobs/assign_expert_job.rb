# frozen_string_literal: true

# Job to automatically assign the best-suited expert to a conversation
# based on the initial message content and expert bios
class AssignExpertJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation
    return if conversation.assigned_expert_id.present? # Already assigned

    # Get the initial message (first message in the conversation)
    initial_message = conversation.messages.order(created_at: :asc).first
    return unless initial_message

    # Get all expert profiles with bios
    expert_profiles = ExpertProfile.includes(:user).where.not(bio: [ nil, "" ])
    return if expert_profiles.empty?

    # Build expert information for the LLM
    expert_info = build_expert_info(expert_profiles)

    # Ask LLM to select the best expert
    best_expert_id = select_best_expert(
      conversation_title: conversation.title,
      initial_message: initial_message.content,
      expert_info: expert_info
    )

    # Assign the expert if one was selected
    if best_expert_id.present?
      assign_expert_to_conversation(conversation, best_expert_id)
    end
  rescue => e
    Rails.logger.error("Failed to assign expert to conversation #{conversation_id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
  end

  private

  def build_expert_info(expert_profiles)
    expert_profiles.map do |profile|
      {
        id: profile.user_id,
        username: profile.user.username,
        bio: profile.bio
      }
    end
  end

  def select_best_expert(conversation_title:, initial_message:, expert_info:)
    client = BedrockClient.new(
      model_id: "anthropic.claude-3-5-haiku-20241022-v1:0"
    )

    system_prompt = build_system_prompt
    user_prompt = build_user_prompt(
      conversation_title: conversation_title,
      initial_message: initial_message,
      expert_info: expert_info
    )

    response = client.call(
      system_prompt: system_prompt,
      user_prompt: user_prompt,
      max_tokens: 200,
      temperature: 0.3
    )

    parse_expert_id_from_response(response[:output_text])
  end

  def build_system_prompt
    <<~PROMPT.strip
      You are an expert routing assistant for a help desk system.
      Your job is to match user questions with the most suitable expert based on their bio.
      
      Rules:
      - Only select an expert if their bio clearly indicates expertise relevant to the question
      - If no expert is clearly suited, respond with "NONE"
      - If an expert is suited, respond with ONLY their expert ID number
      - Do not explain your reasoning, just provide the ID or "NONE"
    PROMPT
  end

  def build_user_prompt(conversation_title:, initial_message:, expert_info:)
    experts_text = expert_info.map do |expert|
      "Expert ID: #{expert[:id]}\nUsername: #{expert[:username]}\nBio: #{expert[:bio]}"
    end.join("\n\n---\n\n")

    <<~PROMPT.strip
      Question Title: #{conversation_title}
      
      Question Content:
      #{initial_message}
      
      Available Experts:
      #{experts_text}
      
      Who is the best expert for this question? Respond with just the expert ID number or "NONE".
    PROMPT
  end

  def parse_expert_id_from_response(response_text)
    return nil if response_text.blank?

    cleaned = response_text.strip.upcase
    
    # Check if response is "NONE" or variations
    return nil if cleaned == "NONE" || cleaned.include?("NO EXPERT") || cleaned.include?("NOT SUITED")

    # Extract the first number from the response
    match = response_text.match(/\d+/)
    match ? match[0].to_i : nil
  end

  def assign_expert_to_conversation(conversation, expert_id)
    expert = User.find_by(id: expert_id)
    return unless expert&.is_expert?

    conversation.update!(
      assigned_expert_id: expert_id,
      status: "active"
    )

    # Create expert assignment record
    ExpertAssignment.create!(
      conversation: conversation,
      expert: expert,
      status: "active"
    )

    Rails.logger.info("Automatically assigned expert #{expert.username} (ID: #{expert_id}) to conversation #{conversation.id}")
  end
end
