require "test_helper"

class HealthTest < ActionDispatch::IntegrationTest
  test "GET /health returns status ok" do
    get "/health"
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal "ok", response_data["status"]
  end

  test "GET /health returns timestamp" do
    get "/health"
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert response_data.key?("timestamp")
    # Verify timestamp is in ISO 8601 format
    assert_nothing_raised { Time.iso8601(response_data["timestamp"]) }
  end

  test "GET /health does not require authentication" do
    get "/health"
    assert_response :ok
  end

  test "GET /health timestamp is current" do
    before_time = 1.second.ago
    get "/health"
    after_time = 1.second.from_now

    assert_response :ok
    response_data = JSON.parse(response.body)
    timestamp = Time.iso8601(response_data["timestamp"])

    assert timestamp >= before_time
    assert timestamp <= after_time
  end
end
