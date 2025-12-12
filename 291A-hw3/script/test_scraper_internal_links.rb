#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for WebScraperService internal link filtering
#
# This script tests that the web scraper only follows internal links
# (same domain) and ignores external links.
#
# Usage:
#   bundle exec ruby script/test_scraper_internal_links.rb

require_relative "../config/environment"

puts "=" * 80
puts "Testing WebScraperService Internal Link Filtering"
puts "=" * 80
puts

# Mock HTTP responses for testing
class MockHTTP
  def self.responses
    @responses ||= {}
  end

  def self.set_response(url, html_content)
    responses[url] = html_content
  end

  def self.get_response(url)
    responses[url]
  end
end

# Sample HTML pages
ROOT_PAGE_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <head>
    <title>Root Page - Documentation</title>
  </head>
  <body>
    <h1>Welcome to Our Documentation</h1>
    <p>This is the main documentation page.</p>
    
    <nav>
      <h2>Navigation</h2>
      <ul>
        <li><a href="/getting-started">Getting Started</a></li>
        <li><a href="/api-reference">API Reference</a></li>
        <li><a href="https://github.com/external/repo">GitHub Repo (External)</a></li>
        <li><a href="https://twitter.com/company">Twitter (External)</a></li>
        <li><a href="https://example.com/blog">Blog (Different Domain)</a></li>
      </ul>
    </nav>
    
    <section>
      <h2>Quick Links</h2>
      <a href="/tutorials/basic">Basic Tutorial</a>
      <a href="/tutorials/advanced">Advanced Tutorial</a>
      <a href="https://stackoverflow.com/questions">Stack Overflow (External)</a>
    </section>
  </body>
  </html>
HTML

GETTING_STARTED_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <head>
    <title>Getting Started</title>
  </head>
  <body>
    <h1>Getting Started Guide</h1>
    <p>Learn how to get started with our platform.</p>
    
    <section>
      <h2>Installation</h2>
      <p>Install the dependencies using npm or yarn.</p>
    </section>
    
    <a href="/api-reference">View API Reference</a>
    <a href="https://nodejs.org/docs">Node.js Docs (External)</a>
  </body>
  </html>
HTML

API_REFERENCE_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <head>
    <title>API Reference</title>
  </head>
  <body>
    <h1>API Reference</h1>
    <p>Complete API documentation for all endpoints.</p>
    
    <section>
      <h3>Authentication</h3>
      <p>Use JWT tokens for authentication.</p>
    </section>
    
    <section>
      <h3>Endpoints</h3>
      <p>Available endpoints: /users, /conversations, /messages</p>
    </section>
    
    <a href="/">Back to Home</a>
    <a href="https://jwt.io">Learn about JWT (External)</a>
  </body>
  </html>
HTML

# Override Net::HTTP to use mock responses
module Net
  class HTTP
    alias_method :original_request, :request
    
    def request(req)
      uri = URI.parse("#{use_ssl? ? 'https' : 'http'}://#{address}#{req.path}")
      mock_response = MockHTTP.get_response(uri.to_s)
      
      if mock_response
        response = Net::HTTPOK.new("1.1", "200", "OK")
        response.instance_variable_set(:@body, mock_response)
        response.instance_variable_set(:@read, true)
        response
      else
        # Return 404 for unmocked URLs
        response = Net::HTTPNotFound.new("1.1", "404", "Not Found")
        response.instance_variable_set(:@body, "")
        response.instance_variable_set(:@read, true)
        response
      end
    end
  end
end

# Setup mock responses
BASE_URL = "https://docs.example.com"
MockHTTP.set_response("#{BASE_URL}", ROOT_PAGE_HTML)
MockHTTP.set_response("#{BASE_URL}/", ROOT_PAGE_HTML)
MockHTTP.set_response("#{BASE_URL}/getting-started", GETTING_STARTED_HTML)
MockHTTP.set_response("#{BASE_URL}/api-reference", API_REFERENCE_HTML)

puts "Mock HTTP server configured with:"
puts "  - #{BASE_URL} (root page)"
puts "  - #{BASE_URL}/getting-started"
puts "  - #{BASE_URL}/api-reference"
puts

# Test 1: Verify root page scrapes correctly
puts "-" * 80
puts "Test 1: Scrape root page only (depth 0)"
puts "-" * 80
puts

result = WebScraperService.scrape(BASE_URL, max_depth: 0, timeout: 5)

puts "Result:"
puts result
puts

if result.include?("Welcome to Our Documentation")
  puts "✓ Root page content extracted"
else
  puts "✗ Failed to extract root page content"
end

if result.scan(/URL:/).length == 1
  puts "✓ Only one page scraped (depth 0)"
else
  puts "✗ Multiple pages scraped when depth is 0"
end

puts

# Test 2: Scrape with depth 1 - should follow only internal links
puts "-" * 80
puts "Test 2: Scrape with depth 1 (follow internal links only)"
puts "-" * 80
puts

result = WebScraperService.scrape(BASE_URL, max_depth: 1, timeout: 5)

puts "Pages scraped:"
urls = result.scan(/URL: (.+)/).flatten
urls.each do |url|
  puts "  - #{url}"
end
puts

# Check what was scraped
has_root = result.include?("Welcome to Our Documentation")
has_getting_started = result.include?("Getting Started Guide")
has_api_reference = result.include?("API Reference")
has_external = result.match?(/github\.com|twitter\.com|stackoverflow\.com|nodejs\.org|jwt\.io|example\.com\/blog/)

puts "Content Analysis:"
puts "  #{has_root ? '✓' : '✗'} Root page included"
puts "  #{has_getting_started ? '✓' : '✗'} Getting Started page included"
puts "  #{has_api_reference ? '✓' : '✗'} API Reference page included"
puts "  #{has_external ? '✗' : '✓'} External links NOT followed (correct)"
puts

# Test 3: Verify external URLs are in root page but not followed
puts "-" * 80
puts "Test 3: Verify external links are present but not followed"
puts "-" * 80
puts

external_links_in_content = [
  "github.com",
  "twitter.com",
  "stackoverflow.com",
  "nodejs.org",
  "jwt.io"
]

followed_external = false
external_links_in_content.each do |external_domain|
  if urls.any? { |url| url.include?(external_domain) }
    puts "✗ External domain #{external_domain} was followed (should not happen)"
    followed_external = true
  else
    puts "✓ External domain #{external_domain} was NOT followed"
  end
end

puts

# Test 4: Verify only docs.example.com domain links were followed
puts "-" * 80
puts "Test 4: Verify all followed links are from same domain"
puts "-" * 80
puts

all_same_domain = urls.all? { |url| url.start_with?("https://docs.example.com") }

if all_same_domain
  puts "✓ All scraped URLs are from the same domain (docs.example.com)"
else
  puts "✗ Some URLs are from different domains"
  urls.each do |url|
    unless url.start_with?("https://docs.example.com")
      puts "  - #{url} (WRONG DOMAIN)"
    end
  end
end

puts

# Summary
puts "=" * 80
puts "Test Summary"
puts "=" * 80
puts

tests_passed = [
  { name: "Root page extraction", passed: has_root },
  { name: "Internal links followed", passed: has_getting_started && has_api_reference },
  { name: "External links NOT followed", passed: !has_external && !followed_external },
  { name: "Same domain constraint", passed: all_same_domain }
]

tests_passed.each do |test|
  status = test[:passed] ? "✓ PASSED" : "✗ FAILED"
  puts "#{status}: #{test[:name]}"
end

puts

passed_count = tests_passed.count { |t| t[:passed] }
total_count = tests_passed.length

if passed_count == total_count
  puts "All tests passed! (#{passed_count}/#{total_count})"
  puts
  puts "The WebScraperService correctly:"
  puts "  • Extracts content from pages"
  puts "  • Follows only internal links (same domain)"
  puts "  • Ignores external links to different domains"
  puts "  • Respects the max_depth parameter"
else
  puts "Some tests failed (#{passed_count}/#{total_count} passed)"
end

puts
