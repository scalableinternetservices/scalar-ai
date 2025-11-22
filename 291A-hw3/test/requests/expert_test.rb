require "test_helper"

class ExpertTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(username: "testuser", password: "password123")
    @expert = User.create!(username: "expertuser", password: "password123")
    @expert_profile = ExpertProfile.create!(user: @expert, bio: "Expert developer", knowledge_base_links: [ "https://example.com" ])
    @token = JwtService.encode(@user)
    @expert_token = JwtService.encode(@expert)
  end

  test "GET /expert/queue returns waiting and assigned conversations" do
    waiting_conv = Conversation.create!(title: "Waiting Conversation", initiator: @user, status: "waiting")
    assigned_conv = Conversation.create!(title: "Assigned Conversation", initiator: @user, status: "active", assigned_expert: @expert)

    get "/expert/queue", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert response_data.key?("waitingConversations")
    assert response_data.key?("assignedConversations")
    assert_equal 1, response_data["waitingConversations"].length
    assert_equal 1, response_data["assignedConversations"].length
  end

  test "GET /expert/queue requires authentication" do
    get "/expert/queue"
    assert_response :unauthorized
  end

  test "GET /expert/queue requires expert profile" do
    non_expert = User.create!(username: "nonexpert", password: "password123")
    non_expert.expert_profile.destroy if non_expert.expert_profile
    non_expert_token = JwtService.encode(non_expert)

    get "/expert/queue", headers: { "Authorization" => "Bearer #{non_expert_token}" }
    assert_response :forbidden
  end

  test "GET /expert/queue orders waiting conversations by created_at ascending" do
    conv1 = Conversation.create!(title: "First", initiator: @user, status: "waiting")
    sleep 0.01
    conv2 = Conversation.create!(title: "Second", initiator: @user, status: "waiting")
    sleep 0.01
    conv3 = Conversation.create!(title: "Third", initiator: @user, status: "waiting")

    get "/expert/queue", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    waiting = JSON.parse(response.body)["waitingConversations"]
    assert_equal "First", waiting[0]["title"]
    assert_equal "Second", waiting[1]["title"]
    assert_equal "Third", waiting[2]["title"]
  end

  test "GET /expert/queue orders assigned conversations by updated_at descending" do
    conv1 = Conversation.create!(title: "First", initiator: @user, status: "active", assigned_expert: @expert)
    sleep 0.01
    conv2 = Conversation.create!(title: "Second", initiator: @user, status: "active", assigned_expert: @expert)
    sleep 0.01
    conv3 = Conversation.create!(title: "Third", initiator: @user, status: "active", assigned_expert: @expert)
    conv1.touch # Update to make it most recent

    get "/expert/queue", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    assigned = JSON.parse(response.body)["assignedConversations"]
    assert_equal "First", assigned[0]["title"]
    assert_equal "Third", assigned[1]["title"]
    assert_equal "Second", assigned[2]["title"]
  end

  test "POST /expert/conversations/:conversation_id/claim claims conversation" do
    conversation = Conversation.create!(title: "Test", initiator: @user, status: "waiting")

    post "/expert/conversations/#{conversation.id}/claim", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert response_data["success"]

    conversation.reload
    assert_equal @expert.id, conversation.assigned_expert_id
    assert_equal "active", conversation.status
  end

  test "POST /expert/conversations/:conversation_id/claim creates expert assignment" do
    conversation = Conversation.create!(title: "Test", initiator: @user, status: "waiting")

    assert_difference("ExpertAssignment.count", 1) do
      post "/expert/conversations/#{conversation.id}/claim", headers: { "Authorization" => "Bearer #{@expert_token}" }
    end

    assignment = ExpertAssignment.last
    assert_equal conversation.id, assignment.conversation_id
    assert_equal @expert.id, assignment.expert_id
    assert_equal "active", assignment.status
  end

  test "POST /expert/conversations/:conversation_id/claim requires authentication" do
    conversation = Conversation.create!(title: "Test", initiator: @user, status: "waiting")
    post "/expert/conversations/#{conversation.id}/claim"
    assert_response :unauthorized
  end

  test "POST /expert/conversations/:conversation_id/claim requires expert profile" do
    non_expert = User.create!(username: "nonexpert", password: "password123")
    non_expert.expert_profile.destroy if non_expert.expert_profile
    non_expert_token = JwtService.encode(non_expert)
    conversation = Conversation.create!(title: "Test", initiator: @user, status: "waiting")

    post "/expert/conversations/#{conversation.id}/claim", headers: { "Authorization" => "Bearer #{non_expert_token}" }
    assert_response :forbidden
  end

  test "POST /expert/conversations/:conversation_id/claim fails if already assigned" do
    other_expert = User.create!(username: "otherexpert", password: "password123")
    ExpertProfile.create!(user: other_expert, bio: "Other expert")
    conversation = Conversation.create!(title: "Test", initiator: @user, status: "active", assigned_expert: other_expert)

    post "/expert/conversations/#{conversation.id}/claim", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :unprocessable_entity
    response_data = JSON.parse(response.body)
    assert_equal "Conversation is already assigned to an expert", response_data["error"]
  end

  test "POST /expert/conversations/:conversation_id/unclaim unclaims conversation" do
    conversation = Conversation.create!(title: "Test", initiator: @user, status: "active", assigned_expert: @expert)
    assignment = ExpertAssignment.create!(conversation: conversation, expert: @expert, status: "active")

    post "/expert/conversations/#{conversation.id}/unclaim", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert response_data["success"]

    conversation.reload
    assert_nil conversation.assigned_expert_id
    assert_equal "waiting", conversation.status
  end

  test "POST /expert/conversations/:conversation_id/unclaim updates assignment to resolved" do
    conversation = Conversation.create!(title: "Test", initiator: @user, status: "active", assigned_expert: @expert)
    assignment = ExpertAssignment.create!(conversation: conversation, expert: @expert, status: "active")

    post "/expert/conversations/#{conversation.id}/unclaim", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok

    assignment.reload
    assert_equal "resolved", assignment.status
    assert_not_nil assignment.resolved_at
  end

  test "POST /expert/conversations/:conversation_id/unclaim requires authentication" do
    conversation = Conversation.create!(title: "Test", initiator: @user, status: "active", assigned_expert: @expert)
    post "/expert/conversations/#{conversation.id}/unclaim"
    assert_response :unauthorized
  end

  test "POST /expert/conversations/:conversation_id/unclaim fails if not assigned to user" do
    other_expert = User.create!(username: "otherexpert", password: "password123")
    ExpertProfile.create!(user: other_expert, bio: "Other expert")
    conversation = Conversation.create!(title: "Test", initiator: @user, status: "active", assigned_expert: other_expert)

    post "/expert/conversations/#{conversation.id}/unclaim", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :forbidden
    response_data = JSON.parse(response.body)
    assert_equal "You are not assigned to this conversation", response_data["error"]
  end

  test "GET /expert/profile returns expert profile" do
    get "/expert/profile", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal @expert_profile.id.to_s, response_data["id"]
    assert_equal @expert.id.to_s, response_data["userId"]
    assert_equal "Expert developer", response_data["bio"]
    assert_equal [ "https://example.com" ], response_data["knowledgeBaseLinks"]
  end

  test "GET /expert/profile requires authentication" do
    get "/expert/profile"
    assert_response :unauthorized
  end

  test "GET /expert/profile requires expert profile" do
    non_expert = User.create!(username: "nonexpert", password: "password123")
    non_expert.expert_profile.destroy if non_expert.expert_profile
    non_expert_token = JwtService.encode(non_expert)

    get "/expert/profile", headers: { "Authorization" => "Bearer #{non_expert_token}" }
    assert_response :forbidden
  end

  test "PUT /expert/profile updates expert profile" do
    put "/expert/profile",
        params: { bio: "Updated bio", knowledge_base_links: [ "https://newlink.com" ] },
        headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal "Updated bio", response_data["bio"]
    assert_equal [ "https://newlink.com" ], response_data["knowledgeBaseLinks"]

    @expert_profile.reload
    assert_equal "Updated bio", @expert_profile.bio
    assert_equal [ "https://newlink.com" ], @expert_profile.knowledge_base_links
  end

  test "PUT /expert/profile requires authentication" do
    put "/expert/profile", params: { bio: "Test" }
    assert_response :unauthorized
  end

  test "PUT /expert/profile requires expert profile" do
    non_expert = User.create!(username: "nonexpert", password: "password123")
    non_expert.expert_profile.destroy if non_expert.expert_profile
    non_expert_token = JwtService.encode(non_expert)

    put "/expert/profile",
        params: { bio: "Test" },
        headers: { "Authorization" => "Bearer #{non_expert_token}" }
    assert_response :forbidden
  end

  test "GET /expert/assignments/history returns assignment history" do
    conversation = Conversation.create!(title: "Test", initiator: @user, status: "active", assigned_expert: @expert)
    assignment = ExpertAssignment.create!(
      conversation: conversation,
      expert: @expert,
      status: "resolved",
      resolved_at: Time.current
    )

    get "/expert/assignments/history", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 1, response_data.length
    assert_equal assignment.id.to_s, response_data.first["id"]
    assert_equal conversation.id.to_s, response_data.first["conversationId"]
    assert_equal @expert.id.to_s, response_data.first["expertId"]
    assert_equal "resolved", response_data.first["status"]
  end

  test "GET /expert/assignments/history requires authentication" do
    get "/expert/assignments/history"
    assert_response :unauthorized
  end

  test "GET /expert/assignments/history requires expert profile" do
    non_expert = User.create!(username: "nonexpert", password: "password123")
    non_expert.expert_profile.destroy if non_expert.expert_profile
    non_expert_token = JwtService.encode(non_expert)

    get "/expert/assignments/history", headers: { "Authorization" => "Bearer #{non_expert_token}" }
    assert_response :forbidden
  end

  test "GET /expert/assignments/history orders by assigned_at descending" do
    conv1 = Conversation.create!(title: "First", initiator: @user, status: "resolved")
    conv2 = Conversation.create!(title: "Second", initiator: @user, status: "resolved")
    conv3 = Conversation.create!(title: "Third", initiator: @user, status: "resolved")

    assignment1 = ExpertAssignment.create!(conversation: conv1, expert: @expert, status: "resolved", assigned_at: 3.days.ago)
    assignment2 = ExpertAssignment.create!(conversation: conv2, expert: @expert, status: "resolved", assigned_at: 2.days.ago)
    assignment3 = ExpertAssignment.create!(conversation: conv3, expert: @expert, status: "resolved", assigned_at: 1.day.ago)

    get "/expert/assignments/history", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal assignment3.id.to_s, response_data[0]["id"]
    assert_equal assignment2.id.to_s, response_data[1]["id"]
    assert_equal assignment1.id.to_s, response_data[2]["id"]
  end
end
