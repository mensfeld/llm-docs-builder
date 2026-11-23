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
      include CodeBlocks

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
      # @note Comments, badges, images and blockquote markers inside code are left unchanged
      def transform(content, options = {})
        result = content.dup

        result = remove_frontmatter(result) if options[:remove_frontmatter]
        result = clean_outside_code(result, options.slice(:remove_comments, :remove_badges))
        result = remove_code_examples(result) if options[:remove_code_examples]
        clean_outside_code(result, options.slice(:remove_images, :remove_blockquotes))
      end

      private

      # Code block lines inside a blockquote start with this marker
      QUOTED_CODE_MARKER = /^> ?/

      # Badge image; its destination never crosses a code placeholder
      BADGE_PATTERN = /!\[[^\]]*\]\([^)\u0000]*(?:badge|shield|svg|travis|coveralls|fury)[^)\u0000]*\)/i

      # Badge image wrapped in a link
      LINKED_BADGE_PATTERN = /\[#{BADGE_PATTERN}\]\([^)\u0000]*\)/

      private_constant :QUOTED_CODE_MARKER, :BADGE_PATTERN, :LINKED_BADGE_PATTERN

      # Run removals on content outside code
      #
      # With blockquote removal, code blocks inside a blockquote lose one level of quote markers, like the text
      # around them.
      #
      # @param content [String] markdown content
      # @param options [Hash] removal options
      # @option options [Boolean] :remove_comments remove HTML comments
      # @option options [Boolean] :remove_badges remove badge images
      # @option options [Boolean] :remove_images remove image syntax
      # @option options [Boolean] :remove_blockquotes remove blockquote formatting
      # @return [String] cleaned content
      def clean_outside_code(content, options)
        return content unless options.values.any?

        unquote = ->(code) { code.start_with?('>') ? code.gsub(QUOTED_CODE_MARKER, '') : code }

        outside_code(content, block_code: (unquote if options[:remove_blockquotes])) do |text|
          text = remove_comments(text) if options[:remove_comments]
          text = remove_badges(text) if options[:remove_badges]
          text = remove_images(text) if options[:remove_images]
          text = remove_blockquotes(text) if options[:remove_blockquotes]
          text
        end
      end

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
        content.gsub(LINKED_BADGE_PATTERN, '').gsub(BADGE_PATTERN, '')
      end

      # Remove code blocks and inline code
      #
      # @param content [String] markdown content
      # @return [String] content without code
      def remove_code_examples(content)
        content = replace_code_blocks(content) { '' }
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
        content = content.gsub(/!\[([^\]]*)\]\([^)\u0000]+\)/, '')
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
