# frozen_string_literal: true

require "test_helper"

class AutoRespondToQuestionJobTest < ActiveJob::TestCase
  def setup
    @initiator = User.create!(username: "asker2", password: "password")
    @expert_user = User.create!(username: "expert2", password: "password")
    ExpertProfile.create!(user: @expert_user, expert_faq: "Q: How?\nA: Like this.")

    @conversation = Conversation.create!(
      title: "Need help",
      initiator: @initiator,
      assigned_expert: @expert_user,
      status: "active"
    )
  end

  def teardown
    clear_enqueued_jobs
    Message.delete_all
    Conversation.delete_all
    ExpertProfile.delete_all
    User.delete_all
  end

  test "invokes auto responder service" do
    question = @conversation.messages.create!(
      sender: @initiator,
      sender_role: "initiator",
      content: "How do I do this?"
    )

    AutoResponderService.expects(:respond_if_applicable).with(question)

    perform_enqueued_jobs do
      AutoRespondToQuestionJob.perform_later(question.id)
    end
  end

  test "no-op when message missing" do
    AutoResponderService.expects(:respond_if_applicable).never

    perform_enqueued_jobs do
      AutoRespondToQuestionJob.perform_later("missing")
    end
  end
end
