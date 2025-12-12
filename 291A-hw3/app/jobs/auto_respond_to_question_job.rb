# frozen_string_literal: true

# Job that attempts to auto-respond to the first question in a conversation.
class AutoRespondToQuestionJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message

    AutoResponderService.respond_if_applicable(message)
  end
end
