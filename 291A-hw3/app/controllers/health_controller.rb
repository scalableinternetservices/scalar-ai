class HealthController < ApplicationController
  def index
    render json: {
      status: "ok",
      timestamp: Time.current.iso8601
    }, status: :ok
  end
end
