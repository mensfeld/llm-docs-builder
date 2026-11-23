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
      # @yieldparam text [String] cleaned content with code replaced by placeholders, so that a later step can
      #   skip code without detecting it again
      # @yieldreturn [String] content to restore the code into
      # @return [String] transformed content
      # @note Comments, badges, images and blockquote markers inside code are left unchanged
      def transform(content, options = {}, &)
        result = content.dup

        result = remove_frontmatter(result) if options[:remove_frontmatter]
        return clean_outside_code(result, options, &) unless options[:remove_code_examples]

        result = remove_code_examples(result, options)
        result = remove_images(result) if options[:remove_images]
        result = remove_blockquotes(result) if options[:remove_blockquotes]
        block_given? ? yield(result) : result
      end

      private

      # Code block lines inside a blockquote start with this marker
      QUOTED_CODE_MARKER = /^> ?/

      # Badge image; its destination never crosses a code placeholder
      BADGE_PATTERN = /!\[[^\]]*\]\([^)\u0000]*(?:badge|shield|svg|travis|coveralls|fury)[^)\u0000]*\)/i

      # Badge image wrapped in a link
      LINKED_BADGE_PATTERN = /\[#{BADGE_PATTERN}\]\([^)\u0000]*\)/

      # Text that each removal outside code can change
      REMOVABLE_PATTERNS = {
        remove_comments: /<!--/,
        remove_badges: BADGE_PATTERN,
        remove_images: /!\[/,
        remove_blockquotes: /^>/
      }.freeze

      private_constant :QUOTED_CODE_MARKER, :BADGE_PATTERN, :LINKED_BADGE_PATTERN, :REMOVABLE_PATTERNS

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
      # @yieldparam text [String] cleaned content with code replaced by placeholders
      # @yieldreturn [String] content to restore the code into
      # @return [String] cleaned content
      # @note Without a block, code is detected only when a removal can change the content
      def clean_outside_code(content, options)
        removals = REMOVABLE_PATTERNS.select { |option, pattern| options[option] && content.match?(pattern) }
        return content if removals.empty? && !block_given?

        if removals.key?(:remove_blockquotes)
          unquote = ->(code) { code.start_with?('>') ? code.gsub(QUOTED_CODE_MARKER, '') : code }
        end

        outside_code(content, block_code: unquote) do |text|
          text = remove_comments(text) if removals.key?(:remove_comments)
          text = remove_badges(text) if removals.key?(:remove_badges)
          text = remove_images(text) if removals.key?(:remove_images)
          text = remove_blockquotes(text) if removals.key?(:remove_blockquotes)
          block_given? ? yield(text) : text
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
      # Comments and badges are removed in the same code scan, before the code, so that code holding a comment
      # marker does not end or start a comment.
      #
      # @param content [String] markdown content
      # @param options [Hash] removal options
      # @option options [Boolean] :remove_comments remove HTML comments
      # @option options [Boolean] :remove_badges remove badge images
      # @return [String] content without code
      def remove_code_examples(content, options)
        content = outside_code(content, block_code: ->(_code) { '' }) do |text|
          text = remove_comments(text) if options[:remove_comments]
          text = remove_badges(text) if options[:remove_badges]
          text
        end
        # Remove inline code
        content.gsub(/`[^`]+`/, '')
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
