# frozen_string_literal: true

module LlmDocsBuilder
  module Transformers
    # Transformer for whitespace normalization
    #
    # Reduces excessive blank lines and trailing whitespace to make
    # content more compact for LLM consumption.
    #
    # @api public
    class WhitespaceTransformer
      include BaseTransformer

      # Transform content by normalizing whitespace
      #
      # @param content [String] markdown content
      # @param options [Hash] transformation options
      # @option options [Boolean] :normalize_whitespace enable normalization
      # @return [String] transformed content
      def transform(content, options = {})
        return content unless options[:normalize_whitespace]

        normalize_whitespace(content)
      end

      private

      # Normalize excessive whitespace
      #
      # @param content [String] markdown content
      # @return [String] content with normalized whitespace
      def normalize_whitespace(content)
        # Remove trailing whitespace from each line
        content = content.gsub(/ +$/, '')

        # Reduce multiple consecutive blank lines to maximum of 2
        content = content.gsub(/\n{4,}/, "\n\n\n")

        # Trim leading and trailing whitespace
        content.strip
      end
    end
  end
end
