# frozen_string_literal: true

module LlmDocsBuilder
  # Transforms markdown files to be AI-friendly
  #
  # Processes individual markdown files to make them more suitable for LLM consumption by
  # expanding relative links to absolute URLs and converting HTML URLs to markdown-friendly
  # formats.
  #
  # @example Transform with base URL
  #   transformer = LlmDocsBuilder::MarkdownTransformer.new('README.md',
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
    # @option options [Boolean] :remove_comments remove HTML comments from markdown
    # @option options [Boolean] :normalize_whitespace normalize excessive whitespace
    # @option options [Boolean] :remove_badges remove badge/shield images
    # @option options [Boolean] :remove_frontmatter remove YAML/TOML frontmatter
    def initialize(file_path, options = {})
      @file_path = file_path
      @options = options
    end

    # Transform markdown content to be AI-friendly
    #
    # Applies transformations to make the markdown more suitable for LLM processing:
    # - Removes YAML/TOML frontmatter (if remove_frontmatter enabled)
    # - Expands relative links to absolute URLs (if base_url provided)
    # - Converts HTML URLs to markdown format (if convert_urls enabled)
    # - Removes HTML comments (if remove_comments enabled)
    # - Removes badge/shield images (if remove_badges enabled)
    # - Normalizes excessive whitespace (if normalize_whitespace enabled)
    #
    # @return [String] transformed markdown content
    def transform
      content = File.read(file_path)

      # Remove frontmatter first (before any other processing)
      content = remove_frontmatter(content) if options[:remove_frontmatter]

      # Link transformations
      content = expand_relative_links(content) if options[:base_url]
      content = convert_html_urls(content) if options[:convert_urls]

      # Content cleanup
      content = remove_comments(content) if options[:remove_comments]
      content = remove_badges(content) if options[:remove_badges]

      # Whitespace normalization last (after all other transformations)
      content = normalize_whitespace(content) if options[:normalize_whitespace]

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

    # Remove HTML comments from markdown content
    #
    # Strips out HTML comments (<!-- ... -->) which are typically metadata for developers
    # and not relevant for LLM consumption. This reduces token usage and improves clarity.
    #
    # Handles:
    # - Single-line comments: <!-- comment -->
    # - Multi-line comments spanning multiple lines
    # - Multiple comments in the same content
    #
    # @param content [String] markdown content to process
    # @return [String] content with comments removed
    def remove_comments(content)
      # Remove HTML comments (single and multi-line)
      # The .*? makes it non-greedy so it stops at the first -->
      content.gsub(/<!--.*?-->/m, '')
    end

    # Remove badge and shield images from markdown
    #
    # Strips out badge/shield images (typically from shields.io, badge.fury.io, etc.)
    # which are visual indicators for humans but provide no value to LLMs.
    #
    # Recognizes common patterns:
    # - [![Badge](badge.svg)](link) (linked badges)
    # - ![Badge](badge.svg) (unlinked badges)
    # - Common badge domains: shields.io, badge.fury.io, travis-ci.org, etc.
    #
    # @param content [String] markdown content to process
    # @return [String] content with badges removed
    def remove_badges(content)
      # Remove linked badges: [![...](badge-url)](link-url)
      content = content.gsub(/\[\!\[([^\]]*)\]\([^\)]*(?:badge|shield|svg|travis|coveralls|fury)[^\)]*\)\]\([^\)]*\)/i, '')

      # Remove standalone badges: ![...](badge-url)
      content = content.gsub(/!\[([^\]]*)\]\([^\)]*(?:badge|shield|svg|travis|coveralls|fury)[^\)]*\)/i, '')

      content
    end

    # Remove YAML or TOML frontmatter from markdown
    #
    # Strips out frontmatter blocks which are metadata used by static site generators
    # (Jekyll, Hugo, etc.) but not relevant for LLM consumption.
    #
    # Recognizes:
    # - YAML frontmatter: --- ... ---
    # - TOML frontmatter: +++ ... +++
    #
    # @param content [String] markdown content to process
    # @return [String] content with frontmatter removed
    def remove_frontmatter(content)
      # Remove YAML frontmatter (--- ... ---)
      content = content.sub(/\A---\s*$.*?^---\s*$/m, '')

      # Remove TOML frontmatter (+++ ... +++)
      content = content.sub(/\A\+\+\+\s*$.*?^\+\+\+\s*$/m, '')

      content
    end

    # Normalize excessive whitespace in markdown
    #
    # Reduces excessive blank lines and trailing whitespace to make content more compact
    # for LLM consumption without affecting readability.
    #
    # Transformations:
    # - Multiple consecutive blank lines (3+) → 2 blank lines max
    # - Trailing whitespace on lines → removed
    # - Leading/trailing whitespace in file → trimmed
    #
    # @param content [String] markdown content to process
    # @return [String] content with normalized whitespace
    def normalize_whitespace(content)
      # Remove trailing whitespace from each line
      content = content.gsub(/ +$/, '')

      # Reduce multiple consecutive blank lines to maximum of 2
      content = content.gsub(/\n{4,}/, "\n\n\n")

      # Trim leading and trailing whitespace from the entire content
      content.strip
    end
  end
end
