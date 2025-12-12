# frozen_string_literal: true

require "net/http"
require "uri"
require "set"
require "nokogiri"

# Service to scrape an HTTPS page and its immediate child links (depth 1) and
# return readable text while avoiding infinite recursion on cycles.
class WebScraperService
  USER_AGENT = "ScalarAI-WebScraperService/1.0"
  BLOCK_ELEMENTS = %w[
    article section nav aside h1 h2 h3 h4 h5 h6 header footer address p hr pre blockquote
    ol ul li dl dt dd figure figcaption main div table thead tbody tfoot tr td th caption
    form fieldset legend details summary
  ].freeze

  def self.scrape(url, max_depth: 1, timeout: 10)
    root = normalize_https_uri(url)
    raise ArgumentError, "URL must be HTTPS" unless root

    visited = Set.new
    results = []

    crawl(root, current_depth: 0, max_depth: max_depth, visited: visited, results: results, timeout: timeout)

    results.map { |entry| format_entry(entry) }.join("\n\n")
  end

  def self.crawl(uri, current_depth:, max_depth:, visited:, results:, timeout:)
    return if visited.include?(uri.to_s)
    visited << uri.to_s

    body = fetch(uri, timeout: timeout)
    return unless body

    document = parse_document(body)
    cleaned_text = clean_document(document)

    results << { url: uri.to_s, text: cleaned_text }

    return if current_depth >= max_depth

    extract_links(document, uri).each do |child_uri|
      crawl(child_uri, current_depth: current_depth + 1, max_depth: max_depth, visited: visited, results: results, timeout: timeout)
    end
  end
  private_class_method :crawl

  def self.fetch(uri, timeout:)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = timeout
    http.read_timeout = timeout

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = USER_AGENT

    response = http.request(request)
    response.is_a?(Net::HTTPSuccess) ? response.body : nil
  rescue StandardError
    nil
  end
  private_class_method :fetch

  def self.parse_document(body)
    Nokogiri::HTML(body)
  rescue StandardError
    Nokogiri::HTML("")
  end
  private_class_method :parse_document

  def self.clean_document(document)
    sanitized = document.dup
    sanitized.search("script,style,noscript,svg,canvas").remove

    tokens = []

    sanitized.traverse do |node|
      if node.text?
        text = node.text.gsub(/\s+/, " ").strip
        tokens << text unless text.empty?
      elsif node.element? && BLOCK_ELEMENTS.include?(node.name.downcase)
        tokens << "\n"
      end
    end

    combined = tokens.join(" ")
    combined.split("\n").map { |line| line.strip }.reject(&:empty?).join("\n")
  end
  private_class_method :clean_document

  def self.extract_links(document, base_uri)
    document.css("a[href]").filter_map do |node|
      href = node["href"]
      next unless href

      begin
        candidate = URI.join(base_uri, href)
      rescue URI::Error
        next
      end

      next unless candidate.scheme == "https"

      candidate.fragment = nil
      candidate
    end.uniq
  end
  private_class_method :extract_links

  def self.normalize_https_uri(url)
    uri = URI.parse(url)
    return unless uri.scheme == "https"
    uri
  rescue URI::Error
    nil
  end
  private_class_method :normalize_https_uri

  def self.format_entry(entry)
    <<~TEXT.strip
      URL: #{entry[:url]}
      CONTENT:
      #{entry[:text]}
    TEXT
  end
  private_class_method :format_entry
end
