# frozen_string_literal: true

require 'net/http'
require 'uri'

module LlmDocsBuilder
  # Compares content sizes between human and AI versions
  #
  # Helps quantify context window savings by comparing:
  # - Remote URL with different User-Agents (human vs AI bot)
  # - Remote URL with local markdown file
  #
  # @example Compare remote versions
  #   comparator = LlmDocsBuilder::Comparator.new('https://example.com/docs/page.html')
  #   result = comparator.compare
  #   puts "Reduction: #{result[:reduction_percent]}%"
  #
  # @example Compare remote with local file
  #   comparator = LlmDocsBuilder::Comparator.new('https://example.com/docs/page.html',
  #     local_file: 'docs/page.md'
  #   )
  #   result = comparator.compare
  #
  # @api public
  class Comparator
    # Default User-Agent for simulating human browser
    HUMAN_USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0'

    # Default User-Agent for simulating AI bot
    AI_USER_AGENT = 'Claude-Web/1.0 (Anthropic AI Assistant)'

    # Maximum number of redirects to follow before raising an error
    MAX_REDIRECTS = 10

    # @return [String] URL to compare
    attr_reader :url

    # @return [Hash] comparison options
    attr_reader :options

    # Initialize a new comparator
    #
    # @param url [String] URL to fetch and compare
    # @param options [Hash] comparison options
    # @option options [String] :local_file path to local markdown file for comparison
    # @option options [String] :human_user_agent custom User-Agent for human version
    # @option options [String] :ai_user_agent custom User-Agent for AI version
    # @option options [Boolean] :verbose enable verbose output
    def initialize(url, options = {})
      @url = url
      @options = {
        human_user_agent: HUMAN_USER_AGENT,
        ai_user_agent: AI_USER_AGENT
      }.merge(options)
    end

    # Compare content sizes and calculate reduction
    #
    # @return [Hash] comparison results with keys:
    #   - :human_size [Integer] size of human version in bytes
    #   - :ai_size [Integer] size of AI version in bytes
    #   - :reduction_bytes [Integer] bytes saved
    #   - :reduction_percent [Integer] percentage reduction
    #   - :factor [Float] compression factor
    #   - :human_source [String] source description (URL or file)
    #   - :ai_source [String] source description (URL or file)
    def compare
      if options[:local_file]
        compare_with_local_file
      else
        compare_remote_versions
      end
    end

    private

    # Compare remote URL (human User-Agent) with remote URL (AI User-Agent)
    #
    # @return [Hash] comparison results
    def compare_remote_versions
      puts "Fetching human version from #{url}..." if options[:verbose]
      human_content = fetch_url(url, options[:human_user_agent])

      puts "Fetching AI version from #{url}..." if options[:verbose]
      ai_content = fetch_url(url, options[:ai_user_agent])

      calculate_results(
        human_content.bytesize,
        ai_content.bytesize,
        "#{url} (User-Agent: human)",
        "#{url} (User-Agent: AI)"
      )
    end

    # Compare remote URL (human User-Agent) with local markdown file
    #
    # @return [Hash] comparison results
    def compare_with_local_file
      local_file = options[:local_file]

      unless File.exist?(local_file)
        raise(
          Errors::GenerationError,
          "Local file not found: #{local_file}"
        )
      end

      puts "Fetching human version from #{url}..." if options[:verbose]
      human_content = fetch_url(url, options[:human_user_agent])

      puts "Reading local file #{local_file}..." if options[:verbose]
      ai_content = File.read(local_file)

      calculate_results(
        human_content.bytesize,
        ai_content.bytesize,
        url,
        local_file
      )
    end

    # Fetch URL content with specified User-Agent
    #
    # Follows redirects (up to MAX_REDIRECTS) and handles HTTPS
    #
    # @param url_string [String] URL to fetch
    # @param user_agent [String] User-Agent header value
    # @param redirect_count [Integer] current redirect depth (internal use)
    # @return [String] response body
    # @raise [Errors::GenerationError] if fetch fails or too many redirects
    def fetch_url(url_string, user_agent, redirect_count = 0)
      if redirect_count >= MAX_REDIRECTS
        raise(
          Errors::GenerationError,
          "Too many redirects (#{MAX_REDIRECTS}) when fetching #{url_string}"
        )
      end

      uri = validate_and_parse_url(url_string)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri.request_uri)
      request['User-Agent'] = user_agent

      response = http.request(request)

      case response
      when Net::HTTPSuccess
        response.body
      when Net::HTTPRedirection
        # Follow redirect with incremented counter
        redirect_url = response['location']
        puts "  Redirecting to #{redirect_url}..." if options[:verbose] && redirect_count.positive?
        fetch_url(redirect_url, user_agent, redirect_count + 1)
      else
        raise(
          Errors::GenerationError,
          "Failed to fetch #{url_string}: #{response.code} #{response.message}"
        )
      end
    rescue Errors::GenerationError
      raise
    rescue StandardError => e
      raise(
        Errors::GenerationError,
        "Error fetching #{url_string}: #{e.message}"
      )
    end

    # Validates and parses URL to prevent malformed URLs
    #
    # @param url_string [String] URL to validate and parse
    # @return [URI::HTTP, URI::HTTPS] parsed URI
    # @raise [Errors::GenerationError] if URL is invalid or uses unsupported scheme
    def validate_and_parse_url(url_string)
      uri = URI.parse(url_string)

      # Only allow HTTP and HTTPS schemes
      unless %w[http https].include?(uri.scheme&.downcase)
        raise(
          Errors::GenerationError,
          "Unsupported URL scheme: #{uri.scheme || 'none'} (only http/https allowed)"
        )
      end

      # Ensure host is present
      if uri.host.nil? || uri.host.empty?
        raise(
          Errors::GenerationError,
          "Invalid URL: missing host in #{url_string}"
        )
      end

      uri
    rescue URI::InvalidURIError => e
      raise(
        Errors::GenerationError,
        "Invalid URL format: #{e.message}"
      )
    end

    # Calculate comparison statistics
    #
    # @param human_size [Integer] size of human version in bytes
    # @param ai_size [Integer] size of AI version in bytes
    # @param human_source [String] description of human source
    # @param ai_source [String] description of AI source
    # @return [Hash] comparison results
    def calculate_results(human_size, ai_size, human_source, ai_source)
      reduction_bytes = human_size - ai_size
      reduction_percent = if human_size.positive?
                            ((reduction_bytes.to_f / human_size) * 100).round
                          else
                            0
                          end

      factor = if ai_size.positive?
                 (human_size.to_f / ai_size).round(1)
               else
                 Float::INFINITY
               end

      {
        human_size: human_size,
        ai_size: ai_size,
        reduction_bytes: reduction_bytes,
        reduction_percent: reduction_percent,
        factor: factor,
        human_source: human_source,
        ai_source: ai_source
      }
    end
  end
end
