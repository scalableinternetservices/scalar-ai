# frozen_string_literal: true

require "test_helper"

class AutoResponderServiceTest < ActiveSupport::TestCase
  def setup
    @initiator = User.create!(username: "asker", password: "password")
    @expert_user = User.create!(username: "expert", password: "password")
    @expert_profile = ExpertProfile.create!(user: @expert_user, expert_faq: "Q: How?\nA: Like this.")

    @conversation = Conversation.create!(
      title: "Need help",
      initiator: @initiator,
      assigned_expert: @expert_user,
      status: "active"
    )
  end

  def teardown
    Message.delete_all
    Conversation.delete_all
    ExpertProfile.delete_all
    User.delete_all
  end

  test "responds to first initiator message when FAQ is present" do
    question = @conversation.messages.create!(
      sender: @initiator,
      sender_role: "initiator",
      content: "How do I do this?"
    )

    fake_client = mock
    fake_client.expects(:call).returns({ output_text: "A: Use the FAQ guidance." })
    BedrockClient.expects(:new).returns(fake_client)

    AutoResponderService.respond_if_applicable(question)

    reply = @conversation.messages.order(:created_at).last
    assert_equal @expert_user.id, reply.sender_id
    assert_equal "expert", reply.sender_role
    assert_match "FAQ", reply.content
  end

  test "skips when not the first message from initiator" do
    @conversation.messages.create!(
      sender: @initiator,
      sender_role: "initiator",
      content: "First question"
    )
    question = @conversation.messages.create!(
      sender: @initiator,
      sender_role: "initiator",
      content: "Second question"
    )

    BedrockClient.expects(:new).never

    AutoResponderService.respond_if_applicable(question)

    assert_equal 2, @conversation.messages.count
  end

  test "skips when expert has no FAQ" do
    @expert_profile.update!(expert_faq: nil)
    question = @conversation.messages.create!(
      sender: @initiator,
      sender_role: "initiator",
      content: "How do I do this?"
    )

    BedrockClient.expects(:new).never

    AutoResponderService.respond_if_applicable(question)

    assert_equal 1, @conversation.messages.count
  end
end
