# frozen_string_literal: true

require 'net/http'
require 'uri'

module LlmDocsBuilder
  # Lightweight HTTP client for fetching remote documentation pages.
  #
  # Provides common functionality needed by multiple commands (transform, compare)
  # including strict scheme validation, redirect handling and sensible timeouts.
  class UrlFetcher
    DEFAULT_USER_AGENT = 'llm-docs-builder/1.0 (+https://github.com/mensfeld/llm-docs-builder)'
    MAX_REDIRECTS = 10

    # @param user_agent [String] HTTP user agent header value
    # @param verbose [Boolean] enable redirect logging
    # @param output [IO] IO stream used for redirect logging
    def initialize(user_agent: DEFAULT_USER_AGENT, verbose: false, output: $stdout)
      @user_agent = user_agent
      @verbose = verbose
      @output = output
    end

    # Fetch remote URL content while following redirects.
    #
    # @param url_string [String] URL to fetch
    # @param redirect_count [Integer] current redirect depth (internal use)
    # @return [String] response body
    # @raise [Errors::GenerationError] on invalid URLs, network failures, or redirect loops
    def fetch(url_string, redirect_count = 0)
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
      request['User-Agent'] = @user_agent

      response = http.request(request)

      case response
      when Net::HTTPSuccess
        response.body
      when Net::HTTPRedirection
        redirect_url = absolute_redirect_url(uri, response['location'])
        log_redirect(redirect_url)
        fetch(redirect_url, redirect_count + 1)
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

    private

    def validate_and_parse_url(url_string)
      uri = URI.parse(url_string)

      unless %w[http https].include?(uri.scheme&.downcase)
        raise(
          Errors::GenerationError,
          "Unsupported URL scheme: #{uri.scheme || 'none'} (only http/https allowed)"
        )
      end

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

    def absolute_redirect_url(base_uri, location)
      raise(
        Errors::GenerationError,
        "Redirect missing location header for #{base_uri}"
      ) if location.nil? || location.empty?

      URI.join(base_uri, location).to_s
    rescue URI::InvalidURIError => e
      raise(
        Errors::GenerationError,
        "Invalid redirect URL from #{base_uri}: #{e.message}"
      )
    end

    def log_redirect(url)
      return unless @verbose

      @output.puts("  Redirecting to #{url}...")
    end
  end
end

