#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for automatic expert assignment feature
#
# This script tests the AssignExpertJob to ensure:
# 1. The job can analyze expert bios
# 2. The LLM selects the best-suited expert
# 3. Conversations get automatically assigned when appropriate
#
# Usage:
#   bundle exec ruby script/test_auto_assignment.rb

require_relative "../config/environment"

puts "=" * 80
puts "Testing Automatic Expert Assignment"
puts "=" * 80
puts

# Enable Bedrock calls
ENV["ALLOW_BEDROCK_CALL"] = "true"

# Setup test data
puts "Setting up test data..."
puts

# Create test users
initiator = User.find_or_create_by!(username: "test_user_#{Time.now.to_i}") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
end
puts "✓ Created initiator: #{initiator.username}"

# Create experts with different specialties
database_expert = User.find_or_create_by!(username: "db_expert_#{Time.now.to_i}") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
end

web_expert = User.find_or_create_by!(username: "web_expert_#{Time.now.to_i}") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
end

python_expert = User.find_or_create_by!(username: "python_expert_#{Time.now.to_i}") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
end

# Create expert profiles with specific bios
database_expert.create_expert_profile!(
  bio: "I specialize in database design, SQL optimization, and PostgreSQL/MySQL administration. I have 10 years of experience with database indexing, query performance tuning, and data modeling."
)
puts "✓ Created database expert: #{database_expert.username}"

web_expert.create_expert_profile!(
  bio: "I'm a frontend developer specializing in React, Vue.js, and modern web technologies. I help with CSS, JavaScript, responsive design, and web performance optimization."
)
puts "✓ Created web expert: #{web_expert.username}"

python_expert.create_expert_profile!(
  bio: "Python developer with expertise in Django, Flask, data science libraries (pandas, numpy), and Python best practices. I can help with web scraping, API development, and Python debugging."
)
puts "✓ Created Python expert: #{python_expert.username}"

puts

# Test Case 1: Database question
puts "-" * 80
puts "Test 1: Database-related question"
puts "-" * 80
puts

conversation1 = initiator.initiated_conversations.create!(
  title: "How to optimize slow database queries?"
)
puts "Created conversation: '#{conversation1.title}'"

message1 = conversation1.messages.create!(
  sender: initiator,
  sender_role: "initiator",
  content: "My SQL queries are running very slow. I have a table with millions of rows and SELECT queries take over 30 seconds. How can I optimize this? Should I add indexes?"
)
puts "Created message: '#{message1.content[0..80]}...'"
puts
puts "Triggering automatic expert assignment..."
puts

# The job should be enqueued, let's run it synchronously for testing
AssignExpertJob.perform_now(conversation1.id)

conversation1.reload
if conversation1.assigned_expert_id
  puts "✓ Conversation automatically assigned to: #{conversation1.assigned_expert.username}"
  puts "  Expected: #{database_expert.username}"
  puts "  Match: #{conversation1.assigned_expert_id == database_expert.id ? '✓ YES' : '✗ NO'}"
else
  puts "✗ No expert was assigned"
end

puts

# Test Case 2: Web development question
puts "-" * 80
puts "Test 2: Web development question"
puts "-" * 80
puts

conversation2 = initiator.initiated_conversations.create!(
  title: "React component not re-rendering"
)

message2 = conversation2.messages.create!(
  sender: initiator,
  sender_role: "initiator",
  content: "I'm having trouble with my React component. When I update the state, the component doesn't re-render. I'm using useState hook but the UI doesn't update. What could be wrong?"
)
puts "Created conversation: '#{conversation2.title}'"
puts "Created message: '#{message2.content[0..80]}...'"
puts
puts "Triggering automatic expert assignment..."
puts

AssignExpertJob.perform_now(conversation2.id)

conversation2.reload
if conversation2.assigned_expert_id
  puts "✓ Conversation automatically assigned to: #{conversation2.assigned_expert.username}"
  puts "  Expected: #{web_expert.username}"
  puts "  Match: #{conversation2.assigned_expert_id == web_expert.id ? '✓ YES' : '✗ NO'}"
else
  puts "✗ No expert was assigned"
end

puts

# Test Case 3: Python question
puts "-" * 80
puts "Test 3: Python programming question"
puts "-" * 80
puts

conversation3 = initiator.initiated_conversations.create!(
  title: "Help with pandas DataFrame filtering"
)

message3 = conversation3.messages.create!(
  sender: initiator,
  sender_role: "initiator",
  content: "I need help filtering a pandas DataFrame. I want to select rows where column A is greater than 100 and column B contains 'test'. How do I do this efficiently in Python?"
)
puts "Created conversation: '#{conversation3.title}'"
puts "Created message: '#{message3.content[0..80]}...'"
puts
puts "Triggering automatic expert assignment..."
puts

AssignExpertJob.perform_now(conversation3.id)

conversation3.reload
if conversation3.assigned_expert_id
  puts "✓ Conversation automatically assigned to: #{conversation3.assigned_expert.username}"
  puts "  Expected: #{python_expert.username}"
  puts "  Match: #{conversation3.assigned_expert_id == python_expert.id ? '✓ YES' : '✗ NO'}"
else
  puts "✗ No expert was assigned"
end

puts

# Test Case 4: Ambiguous question (should not assign)
puts "-" * 80
puts "Test 4: Ambiguous question (no clear match)"
puts "-" * 80
puts

conversation4 = initiator.initiated_conversations.create!(
  title: "General help needed"
)

message4 = conversation4.messages.create!(
  sender: initiator,
  sender_role: "initiator",
  content: "I need some general advice about my project timeline and team management."
)
puts "Created conversation: '#{conversation4.title}'"
puts "Created message: '#{message4.content[0..80]}...'"
puts
puts "Triggering automatic expert assignment..."
puts

AssignExpertJob.perform_now(conversation4.id)

conversation4.reload
if conversation4.assigned_expert_id
  puts "✗ Conversation was assigned to: #{conversation4.assigned_expert.username}"
  puts "  Expected: No assignment (ambiguous question)"
else
  puts "✓ No expert was assigned (correct - question is not technical)"
end

puts

# Summary
puts "=" * 80
puts "Test Summary"
puts "=" * 80
puts

test_results = [
  { name: "Database question", passed: conversation1.assigned_expert_id == database_expert.id },
  { name: "Web development question", passed: conversation2.assigned_expert_id == web_expert.id },
  { name: "Python question", passed: conversation3.assigned_expert_id == python_expert.id },
  { name: "Ambiguous question", passed: conversation4.assigned_expert_id.nil? }
]

test_results.each do |result|
  status = result[:passed] ? "✓ PASSED" : "✗ FAILED"
  puts "#{status}: #{result[:name]}"
end

puts
passed_count = test_results.count { |r| r[:passed] }
total_count = test_results.length

if passed_count == total_count
  puts "All tests passed! (#{passed_count}/#{total_count})"
  puts
  puts "The automatic expert assignment feature is working correctly:"
  puts "  • Analyzes expert bios using Bedrock LLM"
  puts "  • Matches questions to the best-suited expert"
  puts "  • Leaves conversations unassigned when no clear match exists"
else
  puts "Some tests failed (#{passed_count}/#{total_count} passed)"
  puts
  puts "Note: LLM responses may vary. If a test failed, check if the assignment"
  puts "was reasonable given the expert bios and question content."
end

puts
puts "Cleaning up test data..."
[ conversation1, conversation2, conversation3, conversation4 ].each(&:destroy)
[ initiator, database_expert, web_expert, python_expert ].each(&:destroy)
puts "✓ Test data cleaned up"
puts
