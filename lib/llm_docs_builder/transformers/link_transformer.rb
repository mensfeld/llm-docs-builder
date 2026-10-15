# frozen_string_literal: true

require 'uri'

module LlmDocsBuilder
  module Transformers
    # Transformer for link-related operations
    #
    # Handles expansion of relative links to absolute URLs and conversion of HTML URLs to markdown format.
    #
    # @api public
    class LinkTransformer
      include BaseTransformer

      # Transform links in content
      #
      # @param content [String] markdown content
      # @param options [Hash] transformation options
      # @option options [String] :base_url base URL for expanding relative links
      # @option options [String] :source_path path of the transformed file relative to the
      #   docs root, used to resolve relative links against the file's own directory
      # @option options [Boolean] :convert_urls convert HTML URLs to markdown format
      # @return [String] transformed content
      def transform(content, options = {})
        result = content.dup

        result = expand_relative_links(result, options[:base_url], options[:source_path]) if options[:base_url]
        result = convert_html_urls(result) if options[:convert_urls]
        result = simplify_links(result) if options[:simplify_links]

        result
      end

      private

      # URI schemes that must never be treated as relative paths when expanding
      # links with a base URL (kept in sync with the converter's safe schemes)
      ABSOLUTE_URL_SCHEMES = %w[http https mailto ftp tel].freeze

      # Expand relative links to absolute URLs
      #
      # @param content [String] markdown content
      # @param base_url [String] base URL for expansion
      # @param source_path [String, nil] path of the file relative to the docs root
      # @return [String] content with expanded links
      def expand_relative_links(content, base_url, source_path = nil)
        source_dir = source_path ? File.dirname(source_path) : '.'

        content.gsub(/\[([^\]]+)\]\(([^)]+)\)/) do |match|
          text = ::Regexp.last_match(1)
          url = ::Regexp.last_match(2)

          if url.start_with?('http://', 'https://', '//', '#') || absolute_url_scheme?(url)
            match
          else
            "[#{text}](#{resolve_relative_url(base_url, url, source_dir)})"
          end
        end
      end

      # Resolve a relative link target against the base URL
      #
      # Targets starting with `/` are resolved from the base URL itself, other targets from
      # the source file's directory. `./` and `../` segments are normalized.
      #
      # @param base_url [String] base URL for expansion
      # @param url [String] relative link target
      # @param source_dir [String] directory of the source file relative to the docs root
      # @return [String] expanded URL
      def resolve_relative_url(base_url, url, source_dir)
        path = url.start_with?('/') ? url.delete_prefix('/') : File.join(source_dir, url)
        base = base_url.end_with?('/') ? base_url : "#{base_url}/"

        URI.join(base, path).to_s
      rescue URI::Error
        File.join(base_url, url.gsub(%r{^\./}, ''))
      end

      # Check whether a link target uses a known absolute URI scheme
      #
      # @param url [String] link target
      # @return [Boolean] true when the target already carries its own scheme
      def absolute_url_scheme?(url)
        scheme = url.split(':', 2).first.to_s
        ABSOLUTE_URL_SCHEMES.include?(scheme)
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
