class ConversationsController < ApplicationController
  before_action :authenticate_with_jwt!
  before_action :set_conversation, only: [ :show ]

  def index
    # Get all conversations where user is initiator or assigned expert
    conversations = Conversation.where(initiator_id: current_user.id)
                                .or(Conversation.where(assigned_expert_id: current_user.id))
                                .order(updated_at: :desc)

    render json: conversations.map { |c| conversation_json(c, current_user) }, status: :ok
  end

  def show
    render json: conversation_json(@conversation, current_user), status: :ok
  end

  def create
    conversation = current_user.initiated_conversations.new(conversation_params)

    if conversation.save
      render json: conversation_json(conversation, current_user), status: :created
    else
      render json: { errors: conversation.errors.full_messages }, status: :unprocessable_entity
    end
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
                                .find_by(id: params[:id])

    unless @conversation
      render json: { error: "Conversation not found" }, status: :not_found
    end
  end

  def conversation_params
    params.permit(:title)
  end
end
