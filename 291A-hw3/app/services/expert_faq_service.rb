# frozen_string_literal: true

# Service to build an expert FAQ by scraping knowledge-base links and querying the LLM
class ExpertFaqService
  MAX_LINKS = 5
  MAX_CONTEXT_CHARS = 12_000

  def self.generate_faq(expert_profile)
    links = Array(expert_profile.knowledge_base_links)
              .compact
              .select { |url| url.is_a?(String) && url.start_with?("https://") }

    return "No knowledge base links provided" if links.empty?

    context_chunks = scrape_links(links.first(MAX_LINKS))
    return "Could not retrieve content from knowledge base links" if context_chunks.empty?

    context = context_chunks.join("\n\n")[0...MAX_CONTEXT_CHARS]
    prompt_user = build_user_prompt(expert_profile.user.username, context)

    client = BedrockClient.new(
      model_id: "anthropic.claude-3-5-haiku-20241022-v1:0"
    )

    response = client.call(
      system_prompt: system_prompt,
      user_prompt: prompt_user,
      max_tokens: 700,
      temperature: 0.4
    )

    cleaned = response[:output_text].to_s.strip
    cleaned.length < 20 ? "FAQ unavailable" : cleaned
  rescue => e
    Rails.logger.error("Failed to generate expert FAQ: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    "FAQ unavailable"
  end

  def self.scrape_links(links)
    links.filter_map do |link|
      scraped = WebScraperService.scrape(link, max_depth: 1, timeout: 10)
      next if scraped.to_s.strip.empty?

      <<~SRC.strip
        Source: #{link}
        #{scraped}
      SRC
    rescue StandardError => e
      Rails.logger.warn("Failed to scrape #{link}: #{e.message}")
      nil
    end
  end
  private_class_method :scrape_links

  def self.system_prompt
    <<~PROMPT
      You are an assistant that builds concise, helpful FAQ entries for experts.
      Use only the provided source material. Do not invent details.
      Present up to 6 Q&A pairs. Keep answers short and actionable (1-3 sentences).
    PROMPT
  end
  private_class_method :system_prompt

  def self.build_user_prompt(username, context)
    <<~PROMPT
      Build a FAQ for expert "#{username}" using only the content below.

      Content:
      #{context}

      Return the FAQ as:
      Q: ...
      A: ...
      (repeat)
    PROMPT
  end
  private_class_method :build_user_prompt
end
