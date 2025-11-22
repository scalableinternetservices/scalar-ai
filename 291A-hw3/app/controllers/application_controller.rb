class ApplicationController < ActionController::API
  include ActionController::Cookies

  private

  # Helper method to format user JSON
  def user_json(user)
    {
      id: user.id,
      username: user.username,
      created_at: user.created_at.iso8601,
      last_active_at: user.last_active_at&.iso8601
    }
  end

  # Helper method to format conversation JSON
  def conversation_json(conversation, user)
    {
      id: conversation.id.to_s,
      title: conversation.title,
      status: conversation.status,
      questionerId: conversation.initiator_id.to_s,
      questionerUsername: conversation.initiator.username,
      assignedExpertId: conversation.assigned_expert_id&.to_s,
      assignedExpertUsername: conversation.assigned_expert&.username,
      createdAt: conversation.created_at.iso8601,
      updatedAt: conversation.updated_at.iso8601,
      lastMessageAt: conversation.last_message_at&.iso8601,
      unreadCount: conversation.unread_count_for(user)
    }
  end

  # Helper method to format message JSON
  def message_json(message)
    {
      id: message.id.to_s,
      conversationId: message.conversation_id.to_s,
      senderId: message.sender_id.to_s,
      senderUsername: message.sender.username,
      senderRole: message.sender_role,
      content: message.content,
      timestamp: message.created_at.iso8601,
      isRead: message.is_read
    }
  end

  # Helper method to format expert profile JSON
  def expert_profile_json(profile)
    {
      id: profile.id.to_s,
      userId: profile.user_id.to_s,
      bio: profile.bio,
      knowledgeBaseLinks: profile.knowledge_base_links || [],
      createdAt: profile.created_at.iso8601,
      updatedAt: profile.updated_at.iso8601
    }
  end
end
