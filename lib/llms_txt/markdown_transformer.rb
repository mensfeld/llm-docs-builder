# frozen_string_literal: true

module LlmsTxt
  # Transforms markdown files to be AI-friendly
  #
  # Processes individual markdown files to make them more suitable for LLM consumption by
  # expanding relative links to absolute URLs and converting HTML URLs to markdown-friendly
  # formats.
  #
  # @example Transform with base URL
  #   transformer = LlmsTxt::MarkdownTransformer.new('README.md',
  #     base_url: 'https://myproject.io'
  #   )
  #   content = transformer.transform
  #
  # @api public
  class MarkdownTransformer
    # @return [String] path to markdown file
    attr_reader :file_path

    # @return [Hash] transformation options
    attr_reader :options

    # Initialize a new markdown transformer
    #
    # @param file_path [String] path to markdown file to transform
    # @param options [Hash] transformation options
    # @option options [String] :base_url base URL for expanding relative links
    # @option options [Boolean] :convert_urls convert HTML URLs to markdown format
    def initialize(file_path, options = {})
      @file_path = file_path
      @options = options
    end

    # Transform markdown content to be AI-friendly
    #
    # Applies transformations to make the markdown more suitable for LLM processing:
    # - Expands relative links to absolute URLs (if base_url provided)
    # - Converts HTML URLs to markdown format (if convert_urls enabled)
    #
    # @return [String] transformed markdown content
    def transform
      content = File.read(file_path)

      content = expand_relative_links(content) if options[:base_url]
      content = convert_html_urls(content) if options[:convert_urls]

      content
    end

    private

    # Expand relative links to absolute URLs
    #
    # Converts markdown links like `[text](./path.md)` to `[text](https://base.url/path.md)`.
    # Leaves absolute URLs and anchors unchanged.
    #
    # @param content [String] markdown content to process
    # @return [String] content with expanded links
    def expand_relative_links(content)
      base_url = options[:base_url]

      content.gsub(/\[([^\]]+)\]\(([^)]+)\)/) do |match|
        text = ::Regexp.last_match(1)
        url = ::Regexp.last_match(2)

        if url.start_with?('http://', 'https://', '//', '#')
          match # Already absolute or anchor
        else
          # Clean up relative path
          clean_url = url.gsub(%r{^\./}, '') # Remove leading './'
          expanded_url = File.join(base_url, clean_url)
          "[#{text}](#{expanded_url})"
        end
      end
    end

    # Convert HTML URLs to markdown-friendly format
    #
    # Changes URLs ending in .html or .htm to .md for better LLM understanding
    #
    # @param content [String] markdown content to process
    # @return [String] content with converted URLs
    def convert_html_urls(content)
      content.gsub(%r{https?://[^\s<>]+\.html?(?=[)\s]|$)}) do |url|
        url.sub(/\.html?$/, '.md')
      end
    end
  end
end
