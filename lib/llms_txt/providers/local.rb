# frozen_string_literal: true

module LlmsTxt
  module Providers
    class Local < Base
      def complete(_prompt)
        puts 'Local/template generation mode - LLM integration bypassed' if configuration.verbose

        nil
      end
    end
  end
end
