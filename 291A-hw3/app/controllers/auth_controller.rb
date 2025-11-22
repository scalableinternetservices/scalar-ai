class AuthController < ApplicationController
  before_action :authenticate_with_session!, only: [ :logout, :refresh, :me ]

  def register
    user = User.new(user_params)

    if user.save
      # Create expert profile for new user
      user.create_expert_profile!

      # Set session
      session[:user_id] = user.id

      # Generate JWT token
      token = JwtService.encode(user)

      render json: {
        user: user_json(user),
        token: token
      }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def login
    user = User.find_by(username: params[:username])

    if user&.authenticate(params[:password])
      # Set session
      session[:user_id] = user.id

      # Update last active
      user.update(last_active_at: Time.current)

      # Generate JWT token
      token = JwtService.encode(user)

      render json: {
        user: user_json(user),
        token: token
      }, status: :ok
    else
      render json: { error: "Invalid username or password" }, status: :unauthorized
    end
  end

  def logout
    session[:user_id] = nil
    reset_session

    render json: { message: "Logged out successfully" }, status: :ok
  end

  def refresh
    # Generate new JWT token (requires session)
    token = JwtService.encode(current_user)

    render json: {
      user: user_json(current_user),
      token: token
    }, status: :ok
  end

  def me
    render json: user_json(current_user), status: :ok
  end

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  # Auth controller requires session-only authentication (no JWT tokens)
  def authenticate_with_session!
    unless current_user
      render json: { error: "No session found" }, status: :unauthorized
    end
  end

  def user_params
    params.permit(:username, :password, :password_confirmation)
  end
end
