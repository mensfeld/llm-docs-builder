# frozen_string_literal: true

module LlmDocsBuilder
  # Estimates token count for text content using character-based approximation
  #
  # Provides token estimation without requiring external tokenizer dependencies.
  # Uses the common heuristic that ~4 characters equals 1 token for English text,
  # which works reasonably well for documentation and markdown content.
  #
  # @example Basic usage
  #   estimator = LlmDocsBuilder::TokenEstimator.new
  #   token_count = estimator.estimate("This is a sample text.")
  #
  # @example With custom characters per token
  #   estimator = LlmDocsBuilder::TokenEstimator.new(chars_per_token: 3.5)
  #   token_count = estimator.estimate(content)
  #
  # @api public
  class TokenEstimator
    # Default number of characters per token
    DEFAULT_CHARS_PER_TOKEN = 4.0

    # @return [Float] characters per token ratio
    attr_reader :chars_per_token

    # Initialize a new token estimator
    #
    # @param chars_per_token [Float] number of characters per token (default: 4.0)
    def initialize(chars_per_token: DEFAULT_CHARS_PER_TOKEN)
      @chars_per_token = chars_per_token.to_f
    end

    # Estimate token count for given content
    #
    # @param content [String] text content to estimate tokens for
    # @return [Integer] estimated number of tokens
    def estimate(content)
      return 0 if content.nil? || content.empty?

      (content.length / chars_per_token).round
    end

    # Estimate token count (class method for convenience)
    #
    # @param content [String] text content to estimate tokens for
    # @param chars_per_token [Float] number of characters per token (default: 4.0)
    # @return [Integer] estimated number of tokens
    def self.estimate(content, chars_per_token: DEFAULT_CHARS_PER_TOKEN)
      new(chars_per_token: chars_per_token).estimate(content)
    end
  end
end
