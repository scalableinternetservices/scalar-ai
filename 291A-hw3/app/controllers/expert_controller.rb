class ExpertController < ApplicationController
  before_action :authenticate_with_jwt!
  before_action :ensure_expert!
  before_action :set_conversation, only: [ :claim, :unclaim ]

  def queue
    waiting_conversations = Conversation.where(status: "waiting")
                                       .order(created_at: :asc)

    assigned_conversations = Conversation.where(assigned_expert_id: current_user.id, status: "active")
                                        .order(updated_at: :desc)

    render json: {
      waitingConversations: waiting_conversations.map { |c| conversation_json(c, current_user) },
      assignedConversations: assigned_conversations.map { |c| conversation_json(c, current_user) }
    }, status: :ok
  end

  def claim
    if @conversation.assigned_expert_id.present?
      render json: { error: "Conversation is already assigned to an expert" }, status: :unprocessable_entity
      return
    end

    # Update conversation status and assigned expert, touch will update updated_at
    @conversation.update!(assigned_expert_id: current_user.id, status: "active")

    # Create expert assignment record
    ExpertAssignment.create!(
      conversation: @conversation,
      expert: current_user,
      status: "active"
    )

    render json: { success: true }, status: :ok
  end

  def unclaim
    unless @conversation.assigned_expert_id == current_user.id
      render json: { error: "You are not assigned to this conversation" }, status: :forbidden
      return
    end

    # Update conversation status, touch will update updated_at
    @conversation.update!(assigned_expert_id: nil, status: "waiting")

    # Update expert assignment to resolved
    assignment = @conversation.expert_assignments.find_by(expert_id: current_user.id, status: "active")
    assignment&.update(status: "resolved", resolved_at: Time.current)

    render json: { success: true }, status: :ok
  end

  def profile
    profile = current_user.expert_profile

    if profile
      render json: expert_profile_json(profile), status: :ok
    else
      render json: { error: "Expert profile not found" }, status: :not_found
    end
  end

  def update_profile
    profile = current_user.expert_profile

    unless profile
      render json: { error: "Expert profile not found" }, status: :not_found
      return
    end

    if profile.update(profile_params)
      render json: expert_profile_json(profile), status: :ok
    else
      render json: { errors: profile.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def assignment_history
    assignments = current_user.expert_assignments.includes(:conversation).order(assigned_at: :desc)

    render json: assignments.map { |a|
      {
        id: a.id.to_s,
        conversationId: a.conversation_id.to_s,
        expertId: a.expert_id.to_s,
        status: a.status,
        assignedAt: a.assigned_at.iso8601,
        resolvedAt: a.resolved_at&.iso8601,
        rating: nil # Rating not implemented in this version
      }
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

  def ensure_expert!
    unless current_user&.is_expert?
      render json: { error: "Expert profile required" }, status: :forbidden
    end
  end

  def set_conversation
    @conversation = Conversation.find_by(id: params[:conversation_id])

    unless @conversation
      render json: { error: "Conversation not found" }, status: :not_found
    end
  end

  def profile_params
    params.permit(:bio, knowledge_base_links: [])
  end
end
