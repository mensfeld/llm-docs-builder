# frozen_string_literal: true

module LlmDocsBuilder
  # Provides content transformation functionality
  #
  # This module contains specialized transformers for modifying markdown content,
  # including cleanup operations, link processing, heading normalization, and
  # content enhancement for AI consumption.
  #
  # @api private
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
      # @abstract Subclasses must implement this method and document specific options
      # @param content [String] markdown content
      # @param options [Hash] transformation options
      # @option options [Object] :* options vary by implementation - see specific transformer classes
      # @return [String] transformed content
      # @note Options vary by implementation - see specific transformer classes for supported keys
      def transform(content, options = {})
        raise NotImplementedError, "#{self.class} must implement #transform"
      end

      # Check if transformation should be applied
      #
      # @param options [Hash] transformation options
      # @option options [Object] :* options vary by implementation - see specific transformer classes
      # @return [Boolean] true if transformation should be applied
      # @note Options vary by implementation - see specific transformer classes for supported keys
      def should_transform?(options)
        true
      end
    end
  end
end
