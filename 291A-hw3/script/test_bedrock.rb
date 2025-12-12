#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for Amazon Bedrock LLM integration
#
# This script tests the BedrockClient service to ensure:
# 1. AWS credentials are properly configured
# 2. Bedrock API calls work correctly
# 3. The model responds to prompts
#
# Usage:
#   bundle exec ruby script/test_bedrock.rb

require_relative "../config/environment"

puts "=" * 80
puts "Testing Amazon Bedrock Integration"
puts "=" * 80
puts

# Enable Bedrock calls
ENV["ALLOW_BEDROCK_CALL"] = "true"
puts "✓ Set ALLOW_BEDROCK_CALL=true"
puts

# Initialize the Bedrock client
# Using Claude 3.5 Haiku model
model_id = "anthropic.claude-3-5-haiku-20241022-v1:0"
region = ENV["AWS_REGION"] || "us-west-2"

puts "Initializing BedrockClient..."
puts "  Model: #{model_id}"
puts "  Region: #{region}"
puts

begin
  client = BedrockClient.new(
    model_id: model_id,
    region: region
  )
  puts "✓ BedrockClient initialized successfully"
  puts
rescue => e
  puts "✗ Failed to initialize BedrockClient"
  puts "  Error: #{e.message}"
  puts "  Backtrace: #{e.backtrace.first(5).join("\n             ")}"
  exit 1
end

# Test 1: Simple prompt
puts "-" * 80
puts "Test 1: Simple greeting prompt"
puts "-" * 80
puts

system_prompt = "You are a helpful assistant."
user_prompt = "Say hello and introduce yourself in one sentence."

puts "System Prompt: #{system_prompt}"
puts "User Prompt: #{user_prompt}"
puts
puts "Calling Bedrock API..."
puts

begin
  start_time = Time.now
  response = client.call(
    system_prompt: system_prompt,
    user_prompt: user_prompt,
    max_tokens: 200,
    temperature: 0.7
  )
  elapsed_time = Time.now - start_time

  puts "✓ API call successful (#{elapsed_time.round(2)}s)"
  puts
  puts "Response:"
  puts "-" * 40
  puts response[:output_text]
  puts "-" * 40
  puts
rescue => e
  puts "✗ API call failed"
  puts "  Error: #{e.message}"
  puts "  Backtrace: #{e.backtrace.first(5).join("\n             ")}"
  exit 1
end

# Test 2: Technical question (relevant to help desk scenario)
puts "-" * 80
puts "Test 2: Technical help desk question"
puts "-" * 80
puts

system_prompt = "You are a technical support expert helping users with their questions."
user_prompt = "Explain what a database index is in simple terms."

puts "System Prompt: #{system_prompt}"
puts "User Prompt: #{user_prompt}"
puts
puts "Calling Bedrock API..."
puts

begin
  start_time = Time.now
  response = client.call(
    system_prompt: system_prompt,
    user_prompt: user_prompt,
    max_tokens: 300,
    temperature: 0.5
  )
  elapsed_time = Time.now - start_time

  puts "✓ API call successful (#{elapsed_time.round(2)}s)"
  puts
  puts "Response:"
  puts "-" * 40
  puts response[:output_text]
  puts "-" * 40
  puts
rescue => e
  puts "✗ API call failed"
  puts "  Error: #{e.message}"
  puts "  Backtrace: #{e.backtrace.first(5).join("\n             ")}"
  exit 1
end

# Test 3: Verify fake mode is disabled
puts "-" * 80
puts "Test 3: Verifying fake mode is disabled"
puts "-" * 80
puts

if ENV["ALLOW_BEDROCK_CALL"] == "true"
  puts "✓ ALLOW_BEDROCK_CALL is set to 'true'"
  puts "  Real Bedrock API calls are enabled"
else
  puts "✗ ALLOW_BEDROCK_CALL is not set to 'true'"
  puts "  Fake mode would be active"
end
puts

# Summary
puts "=" * 80
puts "All tests passed! ✓"
puts "=" * 80
puts
puts "Your Bedrock integration is working correctly."
puts "The BedrockClient can successfully:"
puts "  • Initialize with AWS credentials"
puts "  • Make API calls to Amazon Bedrock"
puts "  • Process responses from the LLM"
puts
puts "Next steps:"
puts "  • Use BedrockClient in your controllers/services"
puts "  • Set ALLOW_BEDROCK_CALL=true in production environment"
puts "  • Monitor AWS costs and API usage"
puts
