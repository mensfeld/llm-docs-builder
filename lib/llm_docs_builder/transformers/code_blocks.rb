# frozen_string_literal: true

module LlmDocsBuilder
  module Transformers
    # Detection of fenced and indented code blocks shared by transformers
    #
    # @api private
    module CodeBlocks
      # Opening line of a fenced code block
      FENCE_OPENING = /\A[ \t]*(`{3,}|~{3,})/

      # Blockquote markers at the start of a line
      BLOCKQUOTE_PREFIX = /\A(?: {0,3}> ?)*/

      # Line that starts a list item
      LIST_ITEM = /\A {0,3}(?:[-+*]|\d{1,9}[.)])(?:[ \t]|\s*\z)/

      # ATX heading line
      ATX_HEADING_PATTERN = /\A\#{1,6}(?:[ \t]|\s*\z)/

      # Placeholder that stands in for a protected code fragment; a code block's ends with `b`
      CODE_PLACEHOLDER = /\u0000(\d+)b?\u0000/

      # Inline code span: a backtick run closed by a run of the same length, within one paragraph
      INLINE_CODE = /(?<![`\\])(`+)(?!`)(?:(?!\n[ \t]*\n)[^\u0000])+?(?<!`)\1(?!`)/m

      # Start of an HTML comment or of an inline code span
      COMMENT_OR_BACKTICK = /<!--|`/

      # Start of an inline code span
      BACKTICK = /`/

      # Byte of a backtick
      BACKTICK_BYTE = '`'.ord

      # End of an HTML comment
      COMMENT_END = /-->/

      private_constant :FENCE_OPENING, :BLOCKQUOTE_PREFIX, :LIST_ITEM, :ATX_HEADING_PATTERN, :CODE_PLACEHOLDER,
        :INLINE_CODE, :COMMENT_OR_BACKTICK, :BACKTICK, :BACKTICK_BYTE,
        :COMMENT_END

      private

      # Run a transformation on content with code replaced by placeholders, then restore the code
      #
      # @param content [String] markdown content
      # @param block_code [Proc, nil] maps each code block before it is protected
      # @param comments_first [Boolean] leave backticks inside HTML comments in place, as a comment that starts
      #   first hides them
      # @yieldparam text [String] content with code fragments replaced by placeholders
      # @yieldreturn [String] transformed content
      # @return [String] transformed content with the original code restored
      def outside_code(content, block_code: nil, comments_first: false)
        codes = []
        protect = lambda do |code, block: false|
          codes << code
          "\u0000#{codes.size - 1}#{'b' if block}\u0000"
        end

        text = replace_code_blocks(content) do |code|
          protect.call(block_code ? block_code.call(code) : code, block: true)
        end
        text = if comments_first
                 replace_inline_code_outside_comments(text) { |span| protect.call(span) }
               else
                 text.gsub(INLINE_CODE) { protect.call(::Regexp.last_match(0)) }
               end

        yield(text).gsub(CODE_PLACEHOLDER) { codes[::Regexp.last_match(1).to_i] }
      end

      # Replace inline code spans that do not start inside an HTML comment
      #
      # Scans once: a comment is skipped up to its first `-->`, and an unclosed comment ends the search for
      # comments, as no later `<!--` can be closed either.
      #
      # @param text [String] markdown content
      # @yieldparam span [String] inline code span
      # @yieldreturn [String] replacement for the span
      # @return [String] content with inline code spans replaced
      def replace_inline_code_outside_comments(text)
        scanner = StringScanner.new(text, fixed_anchor: true)
        out = +''
        copied = 0
        start_pattern = COMMENT_OR_BACKTICK

        while scanner.skip_until(start_pattern)
          if text.getbyte(scanner.pos - 1) == BACKTICK_BYTE
            start = scanner.pos -= 1
            length = scanner.skip(INLINE_CODE)
            next scanner.pos += 1 unless length

            out << text.byteslice(copied, start - copied) << yield(text.byteslice(start, length))
            copied = scanner.pos
          elsif !scanner.skip_until(COMMENT_END)
            start_pattern = BACKTICK
          end
        end

        out << text.byteslice(copied, text.bytesize - copied)
      end

      # Replace fenced and indented code blocks
      #
      # Indented lines count as code only after a blank line and outside lists, where they would otherwise be
      # paragraph or list item continuations. Code inside blockquotes is detected after the `>` markers.
      #
      # @param content [String] markdown content
      # @yieldparam code [String] code block lines without the final line break
      # @yieldreturn [String] replacement for the code block
      # @return [String] content with code blocks replaced
      def replace_code_blocks(content, &replacement)
        out = +''
        code = +''
        fence = nil
        fence_depth = 0
        depth = 0
        in_list = false
        prev_blank = true

        content.each_line do |line|
          quote = line.start_with?('>', ' ') ? line[BLOCKQUOTE_PREFIX] : ''
          body = quote.empty? ? line : line.delete_prefix(quote)
          prev_blank ||= quote.count('>') > depth
          depth = quote.count('>')
          fence = nil if depth < fence_depth

          if fence
            code << line
            fence = nil if depth == fence_depth && closing_fence?(body, fence)
            prev_blank = true
            next
          end

          if !in_list && (prev_blank || !code.empty?) && indented_code?(body)
            code << line
            next
          end

          if (fence = fence_opening(body))
            fence_depth = depth
            in_list = in_list_after?(body, in_list, prev_blank)
            code << line
            next
          end

          out << replace_lines(code, &replacement) << line
          code = +''
          in_list = in_list_after?(body, in_list, prev_blank)
          prev_blank = body.strip.empty?
        end

        out << replace_lines(code, &replacement)
      end

      # Fence of a line that opens a fenced code block
      #
      # @param line [String] markdown line
      # @return [String, nil] the opening fence, or nil when the line does not open a block
      def fence_opening(line)
        opening = line.match(FENCE_OPENING)
        return unless opening
        return if opening[1].start_with?('`') && opening.post_match.include?('`')

        opening[1]
      end

      # Check whether a line closes a fenced code block
      #
      # @param line [String] markdown line without blockquote markers
      # @param fence [String] the opening fence
      # @return [Boolean] true when the line holds only a fence at least as long as the opening one
      def closing_fence?(line, fence)
        marker = line.strip
        marker.length >= fence.length && marker.count(fence[0]) == marker.length
      end

      # Check whether a line is indented enough to be code
      #
      # @param line [String] markdown line
      # @return [Boolean] true for a non-blank line indented by four spaces or a tab
      def indented_code?(line)
        line.match?(/\A(?: {4}|\t)\s*\S/)
      end

      # Check whether content after a line is still inside a list
      #
      # A line that is not indented ends the list after a blank line, or right away when it is a heading or a fence.
      #
      # @param line [String] markdown line
      # @param in_list [Boolean] whether the previous line was inside a list
      # @param prev_blank [Boolean] whether the previous line was blank
      # @return [Boolean] true when the list continues after this line
      def in_list_after?(line, in_list, prev_blank)
        return true if line.match?(LIST_ITEM)
        return in_list if !in_list || line.strip.empty? || line.match?(/\A[ \t]/)
        return in_list unless prev_blank || line.match?(ATX_HEADING_PATTERN) || fence_opening(line)

        false
      end

      # Replace collected code lines, keeping the final line break
      #
      # @param code [String] collected code lines
      # @yieldparam code [String] code lines without the final line break
      # @yieldreturn [String] replacement for the code lines
      # @return [String] replacement, or an empty string when there is no code
      def replace_lines(code)
        return '' if code.empty?

        body = code.chomp
        "#{yield(body)}#{code.delete_prefix(body)}"
      end
    end
  end
end
