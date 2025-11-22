require "test_helper"

class MessagesTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(username: "testuser", password: "password123")
    @expert = User.create!(username: "expertuser", password: "password123")
    @token = JwtService.encode(@user)
    @expert_token = JwtService.encode(@expert)
    @conversation = Conversation.create!(title: "Test Conversation", initiator: @user, status: "active", assigned_expert: @expert)
  end

  test "GET /conversations/:conversation_id/messages returns messages" do
    message = Message.create!(conversation: @conversation, sender: @user, sender_role: "initiator", content: "Test message")
    get "/conversations/#{@conversation.id}/messages", headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 1, response_data.length
    assert_equal "Test message", response_data.first["content"]
  end

  test "GET /conversations/:conversation_id/messages requires authentication" do
    get "/conversations/#{@conversation.id}/messages"
    assert_response :unauthorized
  end

  test "GET /conversations/:conversation_id/messages requires conversation access" do
    other_user = User.create!(username: "otheruser", password: "password123")
    other_token = JwtService.encode(other_user)
    get "/conversations/#{@conversation.id}/messages", headers: { "Authorization" => "Bearer #{other_token}" }
    assert_response :not_found
  end

  test "GET /conversations/:conversation_id/messages returns messages in chronological order" do
    Message.create!(conversation: @conversation, sender: @user, sender_role: "initiator", content: "First message")
    sleep 0.01
    Message.create!(conversation: @conversation, sender: @expert, sender_role: "expert", content: "Second message")
    sleep 0.01
    Message.create!(conversation: @conversation, sender: @user, sender_role: "initiator", content: "Third message")

    get "/conversations/#{@conversation.id}/messages", headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 3, response_data.length
    assert_equal "First message", response_data[0]["content"]
    assert_equal "Second message", response_data[1]["content"]
    assert_equal "Third message", response_data[2]["content"]
  end

  test "POST /messages creates a new message" do
    post "/messages",
         params: { conversationId: @conversation.id.to_s, content: "New message" },
         headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :created
    response_data = JSON.parse(response.body)
    assert_equal "New message", response_data["content"]
    assert_equal @user.id.to_s, response_data["senderId"]
    assert_equal "initiator", response_data["senderRole"]
  end

  test "POST /messages requires authentication" do
    post "/messages", params: { conversationId: @conversation.id.to_s, content: "Test" }
    assert_response :unauthorized
  end

  test "POST /messages returns 404 for non-existent conversation" do
    post "/messages",
         params: { conversationId: "999999", content: "Test" },
         headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :not_found
  end

  test "POST /messages requires conversation access" do
    other_user = User.create!(username: "otheruser", password: "password123")
    other_token = JwtService.encode(other_user)
    post "/messages",
         params: { conversationId: @conversation.id.to_s, content: "Test" },
         headers: { "Authorization" => "Bearer #{other_token}" }
    assert_response :forbidden
  end

  test "POST /messages sets correct sender_role for initiator" do
    post "/messages",
         params: { conversationId: @conversation.id.to_s, content: "Test message" },
         headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :created
    response_data = JSON.parse(response.body)
    assert_equal "initiator", response_data["senderRole"]
  end

  test "POST /messages sets correct sender_role for expert" do
    post "/messages",
         params: { conversationId: @conversation.id.to_s, content: "Expert reply" },
         headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :created
    response_data = JSON.parse(response.body)
    assert_equal "expert", response_data["senderRole"]
  end

  test "POST /messages includes senderUsername" do
    post "/messages",
         params: { conversationId: @conversation.id.to_s, content: "Test message" },
         headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :created
    response_data = JSON.parse(response.body)
    assert_equal @user.username, response_data["senderUsername"]
  end

  test "PUT /messages/:id/read marks message as read" do
    message = Message.create!(conversation: @conversation, sender: @user, sender_role: "initiator", content: "Test message", is_read: false)
    put "/messages/#{message.id}/read", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert response_data["success"]
    message.reload
    assert message.is_read
  end

  test "PUT /messages/:id/read requires authentication" do
    message = Message.create!(conversation: @conversation, sender: @user, sender_role: "initiator", content: "Test message")
    put "/messages/#{message.id}/read"
    assert_response :unauthorized
  end

  test "PUT /messages/:id/read returns 403 when marking own message as read" do
    message = Message.create!(conversation: @conversation, sender: @user, sender_role: "initiator", content: "Test message")
    put "/messages/#{message.id}/read", headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :forbidden
    response_data = JSON.parse(response.body)
    assert_equal "Cannot mark your own messages as read", response_data["error"]
  end

  test "PUT /messages/:id/read returns 404 for message in conversation without access" do
    other_user = User.create!(username: "otheruser", password: "password123")
    other_conversation = Conversation.create!(title: "Other", initiator: other_user, status: "waiting")
    message = Message.create!(conversation: other_conversation, sender: other_user, sender_role: "initiator", content: "Test")

    put "/messages/#{message.id}/read", headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :not_found
  end

  test "POST /messages updates conversation last_message_at" do
    original_time = @conversation.last_message_at
    sleep 0.01
    post "/messages",
         params: { conversationId: @conversation.id.to_s, content: "New message" },
         headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :created
    @conversation.reload
    assert_not_equal original_time, @conversation.last_message_at
  end

  test "GET /conversations/:conversation_id/messages includes all message fields" do
    message = Message.create!(conversation: @conversation, sender: @user, sender_role: "initiator", content: "Test message", is_read: true)
    get "/conversations/#{@conversation.id}/messages", headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :ok
    response_data = JSON.parse(response.body).first
    assert response_data.key?("id")
    assert response_data.key?("conversationId")
    assert response_data.key?("senderId")
    assert response_data.key?("senderUsername")
    assert response_data.key?("senderRole")
    assert response_data.key?("content")
    assert response_data.key?("timestamp")
    assert response_data.key?("isRead")
  end
end
