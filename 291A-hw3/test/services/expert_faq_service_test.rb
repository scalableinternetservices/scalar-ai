# frozen_string_literal: true

require "test_helper"

class ExpertFaqServiceTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(username: "expert1", password: "password")
    @profile = ExpertProfile.create!(
      user: @user,
      knowledge_base_links: [ "https://example.com" ]
    )
  end

  def teardown
    ExpertProfile.delete_all
    User.delete_all
  end

  test "returns fallback when no knowledge base links are provided" do
    @profile.update!(knowledge_base_links: [])

    result = ExpertFaqService.generate_faq(@profile)

    assert_equal "No knowledge base links provided", result
  end

  test "scrapes links and returns LLM output" do
    WebScraperService.expects(:scrape)
                      .with("https://example.com", max_depth: 1, timeout: 10)
                      .returns("Some scraped content")

    fake_client = mock
    fake_client.expects(:call).returns({ output_text: "Q: What is the purpose?\nA: This is a detailed answer." })
    BedrockClient.expects(:new).returns(fake_client)

    result = ExpertFaqService.generate_faq(@profile)

    assert_match "Q:", result
    assert_match "A:", result
  end

  test "returns fallback when scraping yields no content" do
    WebScraperService.stubs(:scrape).returns("")

    result = ExpertFaqService.generate_faq(@profile)

    assert_equal "Could not retrieve content from knowledge base links", result
  end
end
