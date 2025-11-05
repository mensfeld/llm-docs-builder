# frozen_string_literal: true

module LlmDocsBuilder
  module Helpers
    def squeeze_blank_lines_outside_fences(text, max_blank: 2, fence_chars: %w[` ~], min_fence: 3)
      return '' if text.to_s.empty?

      lines = text.split("\n", -1)

      inside_fence = false
      fence_indent = ''.dup
      fence_char   = nil
      fence_len    = 0

      # Build a fast “does this look like an opening fence?” regex
      # e.g., leading spaces + ``` or ~~~ (length >= min_fence) + optional info string
      fence_set = Regexp.escape(fence_chars.join)
      open_re   = /\A(\s*)([#{fence_set}])\2{#{min_fence - 1},}.*\z/

      out = []
      blank_streak = 0

      lines.each_with_index do |line, _idx|
        if inside_fence
          out << line
          # Closing fence must match indent, char, and fence length
          if line.match?(/\A#{Regexp.escape(fence_indent)}#{Regexp.escape(fence_char * fence_len)}\s*\z/)
            inside_fence = false
            fence_indent = ''.dup
            fence_char   = nil
            fence_len    = 0
          end
          next
        end

        if (m = line.match(open_re))
          # Enter fenced block; compute the *actual* fence length from the line
          fence_indent = m[1]
          fence_char   = m[2]
          after_indent = line[fence_indent.length..]
          fence_len    = after_indent[/\A#{Regexp.escape(fence_char)}+/].length
          inside_fence = true
          blank_streak = 0
          out << line
          next
        end

        # Outside fences: squeeze blank lines
        if line.strip.empty?
          blank_streak += 1
          # Keep at most max_blank blank lines; skip extras
          out << line if blank_streak <= max_blank
        else
          blank_streak = 0
          out << line
        end
      end

      out.join("\n")
    end

    module_function :squeeze_blank_lines_outside_fences
  end
end
