class MessagesController < ApplicationController
  before_action :authenticate_with_jwt!
  before_action :set_conversation, only: [ :index ]
  before_action :set_message, only: [ :mark_read ]

  def index
    messages = @conversation.messages.includes(:sender).order(created_at: :asc)
    render json: messages.map { |m| message_json(m) }, status: :ok
  end

  def create
    conversation = Conversation.find_by(id: params[:conversationId])

    unless conversation
      render json: { error: "Conversation not found" }, status: :not_found
      return
    end

    # Check if user has access to this conversation
    unless conversation.initiator_id == current_user.id || conversation.assigned_expert_id == current_user.id
      render json: { error: "Forbidden" }, status: :forbidden
      return
    end

    # Determine sender role
    sender_role = conversation.initiator_id == current_user.id ? "initiator" : "expert"

    message = conversation.messages.new(
      sender: current_user,
      sender_role: sender_role,
      content: params[:content]
    )

    if message.save
      render json: message_json(message), status: :created
    else
      render json: { errors: message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def mark_read
    # Cannot mark your own messages as read
    if @message.sender_id == current_user.id
      render json: { error: "Cannot mark your own messages as read" }, status: :forbidden
      return
    end

    @message.update(is_read: true)
    render json: { success: true }, status: :ok
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

  def set_conversation
    @conversation = Conversation.where(initiator_id: current_user.id)
                                .or(Conversation.where(assigned_expert_id: current_user.id))
                                .find_by(id: params[:conversation_id])

    unless @conversation
      render json: { error: "Conversation not found" }, status: :not_found
    end
  end

  def set_message
    @message = Message.joins(:conversation)
                     .where("conversations.initiator_id = ? OR conversations.assigned_expert_id = ?",
                            current_user.id, current_user.id)
                     .find_by(id: params[:id])

    unless @message
      render json: { error: "Message not found" }, status: :not_found
    end
  end
end
