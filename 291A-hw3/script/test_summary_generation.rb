#!/usr/bin/env ruby
require_relative "../config/environment"

ENV["ALLOW_BEDROCK_CALL"] = "true"

puts "Creating test users..."
user = User.create!(username: "test_user_#{Time.now.to_i}", password: "password123")
expert = User.create!(username: "expert_#{Time.now.to_i}", password: "password123")

puts "Creating conversation..."
conversation = Conversation.create!(
  title: "Rails deployment question", 
  initiator: user,
  assigned_expert: expert,
  status: "active"
)

puts "Adding messages to conversation..."

# Initial question from user
Message.create!(
  conversation: conversation,
  sender: user,
  sender_role: "initiator",
  content: "How do I deploy a Rails application to AWS? I'm new to deployment and need help setting up everything from scratch."
)

sleep 0.5

# Expert's first response
Message.create!(
  conversation: conversation,
  sender: expert,
  sender_role: "expert",
  content: "Great question! There are several ways to deploy Rails to AWS. The most common approaches are using Elastic Beanstalk, EC2 with Capistrano, or containerized deployment with ECS. Which one interests you most?"
)

sleep 0.5

# User follow-up
Message.create!(
  conversation: conversation,
  sender: user,
  sender_role: "initiator",
  content: "I've heard Elastic Beanstalk is easier for beginners. Can you guide me through that process? What are the prerequisites?"
)

sleep 0.5

# Expert detailed response
Message.create!(
  conversation: conversation,
  sender: expert,
  sender_role: "expert",
  content: "Elastic Beanstalk is indeed beginner-friendly! Prerequisites: 1) AWS account, 2) EB CLI installed, 3) Your Rails app with database.yml configured for production. First, install the EB CLI with 'pip install awsebcli', then run 'eb init' in your project directory."
)

sleep 0.5

# User question about database
Message.create!(
  conversation: conversation,
  sender: user,
  sender_role: "initiator",
  content: "What about the database? Should I use RDS or can I keep using SQLite?"
)

sleep 0.5

# Expert explains database options
Message.create!(
  conversation: conversation,
  sender: expert,
  sender_role: "expert",
  content: "Definitely use RDS for production! SQLite is file-based and won't work well in cloud environments. I recommend PostgreSQL on RDS. Elastic Beanstalk can provision an RDS instance for you during setup. Just select PostgreSQL when prompted."
)

sleep 0.5

# User asks about environment variables
Message.create!(
  conversation: conversation,
  sender: user,
  sender_role: "initiator",
  content: "How do I handle environment variables like SECRET_KEY_BASE and database credentials securely?"
)

sleep 0.5

# Expert explains env vars
Message.create!(
  conversation: conversation,
  sender: expert,
  sender_role: "expert",
  content: "Use EB environment properties! Run 'eb setenv SECRET_KEY_BASE=your_key DATABASE_URL=your_db_url' or set them in the EB console under Configuration > Software. Never commit secrets to your repo. Consider using AWS Secrets Manager for sensitive data."
)

sleep 0.5

# User confirms understanding
Message.create!(
  conversation: conversation,
  sender: user,
  sender_role: "initiator",
  content: "This is really helpful! Let me try setting this up and I'll let you know if I run into any issues. Thanks!"
)

sleep 0.5

# Expert final encouragement
Message.create!(
  conversation: conversation,
  sender: expert,
  sender_role: "expert",
  content: "You're welcome! Feel free to reach out if you hit any snags. Common issues are asset compilation and database migrations - make sure to run 'rake assets:precompile' and 'rake db:migrate' during deployment. Good luck!"
)

puts "\nConversation created with #{conversation.messages.count} messages"
puts "\nGenerating summary..."

GenerateConversationSummaryJob.perform_now(conversation.id)

conversation.reload
puts "\n" + "="*80
puts "CONVERSATION SUMMARY:"
puts "="*80
puts conversation.summary
puts "="*80

puts "\nFull conversation:"
conversation.messages.order(created_at: :asc).each_with_index do |msg, idx|
  puts "\n[Message #{idx + 1}] #{msg.sender.username} (#{msg.sender_role}):"
  puts msg.content
end