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
      ATX_HEADING = /\A\#{1,6}(?:[ \t]|\s*\z)/

      private_constant :FENCE_OPENING, :BLOCKQUOTE_PREFIX, :LIST_ITEM, :ATX_HEADING

      private

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
        return in_list unless prev_blank || line.match?(ATX_HEADING) || fence_opening(line)

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
