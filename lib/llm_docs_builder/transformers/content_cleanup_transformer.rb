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

      # HTML comment
      COMMENT_PATTERN = /<!--.*?-->/m

      # HTML comment or inline code, whichever starts first; only inline code has a first capture group
      COMMENT_OR_INLINE_CODE_PATTERN = /#{COMMENT_PATTERN}|#{INLINE_CODE}/

      # Image alt text; it may hold inline code but never crosses a code block placeholder
      ALT_TEXT_PATTERN = /(?:[^\]\u0000]|\u0000\d+\u0000)*/

      # Inline image; its destination never crosses a code placeholder
      IMAGE_PATTERN = /!\[#{ALT_TEXT_PATTERN}\]\([^)\u0000]+\)/

      # Reference-style image
      REFERENCE_IMAGE_PATTERN = /!\[#{ALT_TEXT_PATTERN}\]\[[^\]\u0000]+\]/

      # Badge image
      BADGE_PATTERN =
        /!\[#{ALT_TEXT_PATTERN}\]\([^)\u0000]*(?:badge|shield|svg|travis|coveralls|fury)[^)\u0000]*\)/i

      # Badge image wrapped in a link
      LINKED_BADGE_PATTERN = /\[#{BADGE_PATTERN}\]\([^)\u0000]*\)/

      # Text that each removal outside code can change
      REMOVABLE_PATTERNS = {
        remove_comments: /<!--/,
        remove_badges: BADGE_PATTERN,
        remove_images: /!\[/,
        remove_blockquotes: /^>/
      }.freeze

      private_constant :QUOTED_CODE_MARKER, :COMMENT_PATTERN, :COMMENT_OR_INLINE_CODE_PATTERN, :ALT_TEXT_PATTERN,
        :IMAGE_PATTERN, :REFERENCE_IMAGE_PATTERN, :BADGE_PATTERN, :LINKED_BADGE_PATTERN, :REMOVABLE_PATTERNS

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

        outside_code(content, block_code: unquote, inline_code: inline_code_pattern(removals)) do |text|
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
        content.gsub(COMMENT_PATTERN, '')
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
        removed = ->(_code) { '' }

        content = outside_code(content, block_code: removed, inline_code: inline_code_pattern(options)) do |text|
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
        content.gsub(IMAGE_PATTERN, '').gsub(REFERENCE_IMAGE_PATTERN, '')
      end

      # Pattern that finds the inline code to protect
      #
      # A comment that starts before a backtick hides it, so with comment removal the comment is matched first.
      #
      # @param options [Hash] removal options
      # @option options [Boolean] :remove_comments remove HTML comments
      # @return [Regexp] inline code pattern for {CodeBlocks#outside_code}
      def inline_code_pattern(options)
        options[:remove_comments] ? COMMENT_OR_INLINE_CODE_PATTERN : INLINE_CODE
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
