# frozen_string_literal: true

module LlmDocsBuilder
  module Helpers
    def prune_trailing_unsafe_link_separator!(parts)
      while parts.any?
        last = parts.last
        new_last = last.sub(/[ \t]*\|\s*\z/, '')

        if new_last != last
          trimmed = new_last.rstrip
          parts[-1] = trimmed
          parts.pop if trimmed.empty?
        elsif last.strip.empty?
          parts.pop
        else
          break
        end
      end
    end

    module_function :prune_trailing_unsafe_link_separator!
  end
end
