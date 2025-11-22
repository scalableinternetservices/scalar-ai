require "test_helper"

class UpdatesTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(username: "testuser", password: "password123")
    @expert = User.create!(username: "expertuser", password: "password123")
    @expert_profile = ExpertProfile.create!(user: @expert, bio: "Expert developer")
    @token = JwtService.encode(@user)
    @expert_token = JwtService.encode(@expert)
  end

  test "GET /api/conversations/updates returns updated conversations" do
    conversation = Conversation.create!(title: "Test", initiator: @user, status: "waiting")

    get "/api/conversations/updates",
        params: { userId: @user.id },
        headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 1, response_data.length
    assert_equal conversation.id.to_s, response_data.first["id"]
  end

  test "GET /api/conversations/updates requires authentication" do
    get "/api/conversations/updates", params: { userId: @user.id }
    assert_response :unauthorized
  end

  test "GET /api/conversations/updates returns 404 for non-existent user" do
    get "/api/conversations/updates",
        params: { userId: 999999 },
        headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :not_found
  end

  test "GET /api/conversations/updates filters by since timestamp" do
    old_conversation = Conversation.create!(title: "Old", initiator: @user, status: "waiting")
    old_conversation.update_column(:updated_at, 2.days.ago)

    since_time = 1.day.ago
    new_conversation = Conversation.create!(title: "New", initiator: @user, status: "waiting")

    get "/api/conversations/updates",
        params: { userId: @user.id, since: since_time.iso8601 },
        headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 1, response_data.length
    assert_equal new_conversation.id.to_s, response_data.first["id"]
  end

  test "GET /api/conversations/updates includes conversations as initiator" do
    conversation = Conversation.create!(title: "As Initiator", initiator: @user, status: "waiting")

    get "/api/conversations/updates",
        params: { userId: @user.id },
        headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 1, response_data.length
  end

  test "GET /api/conversations/updates includes conversations as assigned expert" do
    conversation = Conversation.create!(title: "As Expert", initiator: @user, status: "active", assigned_expert: @expert)

    get "/api/conversations/updates",
        params: { userId: @expert.id },
        headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 1, response_data.length
  end

  test "GET /api/conversations/updates orders by updated_at descending" do
    conv1 = Conversation.create!(title: "First", initiator: @user, status: "waiting")
    sleep 0.01
    conv2 = Conversation.create!(title: "Second", initiator: @user, status: "waiting")
    sleep 0.01
    conv3 = Conversation.create!(title: "Third", initiator: @user, status: "waiting")

    get "/api/conversations/updates",
        params: { userId: @user.id },
        headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal "Third", response_data[0]["title"]
    assert_equal "Second", response_data[1]["title"]
    assert_equal "First", response_data[2]["title"]
  end

  test "GET /api/messages/updates returns new messages" do
    conversation = Conversation.create!(title: "Test", initiator: @user, status: "active", assigned_expert: @expert)
    message = Message.create!(conversation: conversation, sender: @expert, sender_role: "expert", content: "Test message")

    get "/api/messages/updates",
        params: { userId: @user.id },
        headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 1, response_data.length
    assert_equal message.id.to_s, response_data.first["id"]
  end

  test "GET /api/messages/updates requires authentication" do
    get "/api/messages/updates", params: { userId: @user.id }
    assert_response :unauthorized
  end

  test "GET /api/messages/updates returns 404 for non-existent user" do
    get "/api/messages/updates",
        params: { userId: 999999 },
        headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :not_found
  end

  test "GET /api/messages/updates filters by since timestamp" do
    conversation = Conversation.create!(title: "Test", initiator: @user, status: "active", assigned_expert: @expert)
    old_message = Message.create!(conversation: conversation, sender: @user, sender_role: "initiator", content: "Old message")
    old_message.update_column(:created_at, 2.days.ago)

    since_time = 1.day.ago
    new_message = Message.create!(conversation: conversation, sender: @expert, sender_role: "expert", content: "New message")

    get "/api/messages/updates",
        params: { userId: @user.id, since: since_time.iso8601 },
        headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 1, response_data.length
    assert_equal new_message.id.to_s, response_data.first["id"]
  end

  test "GET /api/messages/updates only returns messages from user's conversations" do
    user_conversation = Conversation.create!(title: "User Conv", initiator: @user, status: "waiting")
    other_user = User.create!(username: "otheruser", password: "password123")
    other_conversation = Conversation.create!(title: "Other Conv", initiator: other_user, status: "waiting")

    user_message = Message.create!(conversation: user_conversation, sender: @user, sender_role: "initiator", content: "User message")
    other_message = Message.create!(conversation: other_conversation, sender: other_user, sender_role: "initiator", content: "Other message")

    get "/api/messages/updates",
        params: { userId: @user.id },
        headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 1, response_data.length
    assert_equal user_message.id.to_s, response_data.first["id"]
  end

  test "GET /api/messages/updates orders by created_at descending" do
    conversation = Conversation.create!(title: "Test", initiator: @user, status: "active", assigned_expert: @expert)
    msg1 = Message.create!(conversation: conversation, sender: @user, sender_role: "initiator", content: "First")
    sleep 0.01
    msg2 = Message.create!(conversation: conversation, sender: @expert, sender_role: "expert", content: "Second")
    sleep 0.01
    msg3 = Message.create!(conversation: conversation, sender: @user, sender_role: "initiator", content: "Third")

    get "/api/messages/updates",
        params: { userId: @user.id },
        headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal "Third", response_data[0]["content"]
    assert_equal "Second", response_data[1]["content"]
    assert_equal "First", response_data[2]["content"]
  end

  test "GET /api/expert-queue/updates returns queue updates" do
    waiting_conv = Conversation.create!(title: "Waiting", initiator: @user, status: "waiting")
    assigned_conv = Conversation.create!(title: "Assigned", initiator: @user, status: "active", assigned_expert: @expert)

    get "/api/expert-queue/updates",
        params: { expertId: @expert.id },
        headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert response_data.key?("waitingConversations")
    assert response_data.key?("assignedConversations")
    assert_equal 1, response_data["waitingConversations"].length
    assert_equal 1, response_data["assignedConversations"].length
  end

  test "GET /api/expert-queue/updates requires authentication" do
    get "/api/expert-queue/updates", params: { expertId: @expert.id }
    assert_response :unauthorized
  end

  test "GET /api/expert-queue/updates returns 404 for non-existent expert" do
    get "/api/expert-queue/updates",
        params: { expertId: 999999 },
        headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :not_found
  end

  test "GET /api/expert-queue/updates filters by since timestamp" do
    old_conv = Conversation.create!(title: "Old", initiator: @user, status: "waiting")
    old_conv.update_column(:updated_at, 2.days.ago)

    since_time = 1.day.ago
    new_conv = Conversation.create!(title: "New", initiator: @user, status: "waiting")

    get "/api/expert-queue/updates",
        params: { expertId: @expert.id, since: since_time.iso8601 },
        headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 1, response_data["waitingConversations"].length
    assert_equal new_conv.id.to_s, response_data["waitingConversations"].first["id"]
  end

  test "GET /api/expert-queue/updates waiting conversations ordered by created_at ascending" do
    conv1 = Conversation.create!(title: "First", initiator: @user, status: "waiting")
    sleep 0.01
    conv2 = Conversation.create!(title: "Second", initiator: @user, status: "waiting")
    sleep 0.01
    conv3 = Conversation.create!(title: "Third", initiator: @user, status: "waiting")

    get "/api/expert-queue/updates",
        params: { expertId: @expert.id },
        headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    waiting = JSON.parse(response.body)["waitingConversations"]
    assert_equal "First", waiting[0]["title"]
    assert_equal "Second", waiting[1]["title"]
    assert_equal "Third", waiting[2]["title"]
  end

  test "GET /api/expert-queue/updates assigned conversations ordered by updated_at descending" do
    conv1 = Conversation.create!(title: "First", initiator: @user, status: "active", assigned_expert: @expert)
    sleep 0.01
    conv2 = Conversation.create!(title: "Second", initiator: @user, status: "active", assigned_expert: @expert)
    sleep 0.01
    conv3 = Conversation.create!(title: "Third", initiator: @user, status: "active", assigned_expert: @expert)
    conv1.touch # Make it most recent

    get "/api/expert-queue/updates",
        params: { expertId: @expert.id },
        headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    assigned = JSON.parse(response.body)["assignedConversations"]
    assert_equal "First", assigned[0]["title"]
    assert_equal "Third", assigned[1]["title"]
    assert_equal "Second", assigned[2]["title"]
  end

  test "GET /api/expert-queue/updates only returns active status for assigned conversations" do
    active_conv = Conversation.create!(title: "Active", initiator: @user, status: "active", assigned_expert: @expert)
    resolved_conv = Conversation.create!(title: "Resolved", initiator: @user, status: "resolved", assigned_expert: @expert)

    get "/api/expert-queue/updates",
        params: { expertId: @expert.id },
        headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 1, response_data["assignedConversations"].length
    assert_equal active_conv.id.to_s, response_data["assignedConversations"].first["id"]
  end

  test "GET /api/expert-queue/updates returns object not array" do
    get "/api/expert-queue/updates",
        params: { expertId: @expert.id },
        headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    # Should be an object with keys, not an array
    assert response_data.is_a?(Hash)
    assert_not response_data.is_a?(Array)
  end
end
