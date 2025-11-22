class UpdatesController < ApplicationController
  before_action :authenticate_with_jwt!

  def conversations_updates
    user_id = params[:userId]
    since = params[:since] ? Time.parse(params[:since]) : Time.at(0)

    user = User.find_by(id: user_id)
    unless user
      render json: { error: "User not found" }, status: :not_found
      return
    end

    # Get conversations updated since the given timestamp (inclusive)
    conversations = Conversation.where(initiator_id: user.id)
                                .or(Conversation.where(assigned_expert_id: user.id))
                                .where("updated_at >= ?", since)
                                .order(updated_at: :desc)

    render json: conversations.map { |c| conversation_json(c, user) }, status: :ok
  end

  def messages_updates
    user_id = params[:userId]
    since = params[:since] ? Time.parse(params[:since]) : Time.at(0)

    user = User.find_by(id: user_id)
    unless user
      render json: { error: "User not found" }, status: :not_found
      return
    end

    # Get messages from conversations the user is part of, created since the given timestamp (inclusive)
    conversation_ids = Conversation.where(initiator_id: user.id)
                                   .or(Conversation.where(assigned_expert_id: user.id))
                                   .pluck(:id)

    messages = Message.where(conversation_id: conversation_ids)
                     .where("created_at >= ?", since)
                     .includes(:sender)
                     .order(created_at: :desc)

    render json: messages.map { |m| message_json(m) }, status: :ok
  end

  def expert_queue_updates
    expert_id = params[:expertId]
    since = params[:since] ? Time.parse(params[:since]) : Time.at(0)

    expert = User.find_by(id: expert_id)
    unless expert
      render json: { error: "Expert not found" }, status: :not_found
      return
    end

    # Get waiting conversations updated since timestamp (inclusive)
    waiting_conversations = Conversation.where(status: "waiting")
                                       .where("updated_at >= ?", since)
                                       .order(created_at: :asc)

    # Get assigned conversations updated since timestamp (inclusive)
    assigned_conversations = Conversation.where(assigned_expert_id: expert.id, status: "active")
                                        .where("updated_at >= ?", since)
                                        .order(updated_at: :desc)

    render json: {
      waitingConversations: waiting_conversations.map { |c| conversation_json(c, expert) },
      assignedConversations: assigned_conversations.map { |c| conversation_json(c, expert) }
    }, status: :ok
  end

  private

  def current_user
    @current_user
  end

  def authenticate_with_jwt!
    token = request.headers["Authorization"]&.split(" ")&.last

    unless token
      render json: { error: "No session found" }, status: :unauthorized
      return
    end

    begin
      decoded = JwtService.decode(token)
      @current_user = User.find_by(id: decoded[:user_id])

      unless @current_user
        render json: { error: "No session found" }, status: :unauthorized
      end
    rescue JWT::DecodeError, JWT::ExpiredSignature
      render json: { error: "No session found" }, status: :unauthorized
    end
  end
end
