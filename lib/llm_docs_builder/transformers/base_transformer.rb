# frozen_string_literal: true

module LlmDocsBuilder
  module Transformers
    # Base module for all transformers
    #
    # Provides a common interface for content transformation operations.
    # Each transformer should implement the `transform` method.
    #
    # @api public
    module BaseTransformer
      # Transform content
      #
      # @param content [String] content to transform
      # @param options [Hash] transformation options
      # @return [String] transformed content
      def transform(content, options = {})
        raise NotImplementedError, "#{self.class} must implement #transform"
      end

      # Check if transformation should be applied
      #
      # @param options [Hash] transformation options
      # @return [Boolean] true if transformation should be applied
      def should_transform?(options)
        true
      end
    end
  end
end
