# frozen_string_literal: true

module LlmDocsBuilder
  module Helpers
    def prune_trailing_unsafe_link_separator!(parts)
      return if parts.empty?

      loop do
        break if parts.empty?

        last = parts.last
        new_last = last.sub(/[ \t]*\|\s*\z/, '')

        if new_last != last
          trimmed = new_last.rstrip
          if trimmed.empty?
            parts.pop
          else
            parts[-1] = trimmed
          end
          next
        end

        if last.strip.empty?
          parts.pop
          next
        end

        break
      end
    end

    module_function :prune_trailing_unsafe_link_separator!
  end
end
