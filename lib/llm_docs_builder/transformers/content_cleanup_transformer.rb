# frozen_string_literal: true

module LlmDocsBuilder
  module Transformers
    # Transformer for content cleanup operations
    #
    # Handles removal of various markdown elements that don't provide
    # value for LLM consumption (frontmatter, comments, badges, etc.).
    #
    # @api public
    class ContentCleanupTransformer
      include BaseTransformer

      # Transform content by removing unwanted elements
      #
      # @param content [String] markdown content
      # @param options [Hash] transformation options
      # @option options [Boolean] :remove_frontmatter remove YAML/TOML frontmatter
      # @option options [Boolean] :remove_comments remove HTML comments
      # @option options [Boolean] :remove_badges remove badge images
      # @option options [Boolean] :remove_code_examples remove code blocks
      # @option options [Boolean] :remove_images remove image syntax
      # @option options [Boolean] :remove_blockquotes remove blockquote formatting
      # @return [String] transformed content
      def transform(content, options = {})
        result = content.dup

        result = remove_frontmatter(result) if options[:remove_frontmatter]
        result = remove_comments(result) if options[:remove_comments]
        result = remove_badges(result) if options[:remove_badges]
        result = remove_code_examples(result) if options[:remove_code_examples]
        result = remove_images(result) if options[:remove_images]
        result = remove_blockquotes(result) if options[:remove_blockquotes]

        result
      end

      private

      # Remove YAML or TOML frontmatter
      #
      # @param content [String] markdown content
      # @return [String] content without frontmatter
      def remove_frontmatter(content)
        content = content.sub(/\A---\s*$.*?^---\s*$/m, '')
        content = content.sub(/\A\+\+\+\s*$.*?^\+\+\+\s*$/m, '')
        content
      end

      # Remove HTML comments
      #
      # @param content [String] markdown content
      # @return [String] content without comments
      def remove_comments(content)
        content.gsub(/<!--.*?-->/m, '')
      end

      # Remove badge images
      #
      # @param content [String] markdown content
      # @return [String] content without badges
      def remove_badges(content)
        # Remove linked badges
        content = content.gsub(/\[\!\[([^\]]*)\]\([^\)]*(?:badge|shield|svg|travis|coveralls|fury)[^\)]*\)\]\([^\)]*\)/i, '')
        # Remove standalone badges
        content = content.gsub(/!\[([^\]]*)\]\([^\)]*(?:badge|shield|svg|travis|coveralls|fury)[^\)]*\)/i, '')
        content
      end

      # Remove code blocks and inline code
      #
      # @param content [String] markdown content
      # @return [String] content without code
      def remove_code_examples(content)
        # Remove fenced code blocks
        content = content.gsub(/^```.*?^```/m, '')
        content = content.gsub(/^~~~.*?^~~~/m, '')
        # Remove indented code blocks
        content = content.gsub(/^([ ]{4,}|\t).+$/m, '')
        # Remove inline code
        content = content.gsub(/`[^`]+`/, '')
        content
      end

      # Remove image syntax
      #
      # @param content [String] markdown content
      # @return [String] content without images
      def remove_images(content)
        # Remove inline images
        content = content.gsub(/!\[([^\]]*)\]\([^\)]+\)/, '')
        # Remove reference-style images
        content = content.gsub(/!\[([^\]]*)\]\[[^\]]+\]/, '')
        content
      end

      # Remove blockquote formatting
      #
      # @param content [String] markdown content
      # @return [String] content without blockquote markers
      def remove_blockquotes(content)
        content.gsub(/^>\s?/, '')
      end
    end
  end
end
