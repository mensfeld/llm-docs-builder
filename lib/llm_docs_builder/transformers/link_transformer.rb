# frozen_string_literal: true

module LlmDocsBuilder
  module Transformers
    # Transformer for link-related operations
    #
    # Handles expansion of relative links to absolute URLs and
    # conversion of HTML URLs to markdown format.
    #
    # @api public
    class LinkTransformer
      include BaseTransformer

      # Transform links in content
      #
      # @param content [String] markdown content
      # @param options [Hash] transformation options
      # @option options [String] :base_url base URL for expanding relative links
      # @option options [Boolean] :convert_urls convert HTML URLs to markdown format
      # @return [String] transformed content
      def transform(content, options = {})
        result = content.dup

        result = expand_relative_links(result, options[:base_url]) if options[:base_url]
        result = convert_html_urls(result) if options[:convert_urls]
        result = simplify_links(result) if options[:simplify_links]

        result
      end

      private

      # Expand relative links to absolute URLs
      #
      # @param content [String] markdown content
      # @param base_url [String] base URL for expansion
      # @return [String] content with expanded links
      def expand_relative_links(content, base_url)
        content.gsub(/\[([^\]]+)\]\(([^)]+)\)/) do |match|
          text = ::Regexp.last_match(1)
          url = ::Regexp.last_match(2)

          if url.start_with?('http://', 'https://', '//', '#')
            match
          else
            clean_url = url.gsub(%r{^\./}, '')
            expanded_url = File.join(base_url, clean_url)
            "[#{text}](#{expanded_url})"
          end
        end
      end

      # Convert HTML URLs to markdown format
      #
      # @param content [String] markdown content
      # @return [String] content with converted URLs
      def convert_html_urls(content)
        content.gsub(%r{https?://[^\s<>]+\.html?(?=[)\s]|$)}) do |url|
          url.sub(/\.html?$/, '.md')
        end
      end

      # Simplify verbose link text
      #
      # @param content [String] markdown content
      # @return [String] content with simplified links
      def simplify_links(content)
        content.gsub(/\[([^\]]+)\]\(([^)]+)\)/) do
          text = ::Regexp.last_match(1)
          url = ::Regexp.last_match(2)

          simplified_text = text
                            .gsub(/^(click here to|see|read more about|check out|visit)\s+(the\s+)?/i, '')
                            .gsub(/\s+(here|documentation|docs)$/i, '')
                            .strip

          simplified_text = text if simplified_text.empty?

          "[#{simplified_text}](#{url})"
        end
      end
    end
  end
end
