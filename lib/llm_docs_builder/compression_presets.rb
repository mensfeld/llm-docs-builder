# frozen_string_literal: true

module LlmDocsBuilder
  # Compression preset configurations
  #
  # Provides pre-configured compression levels for easy use.
  # Each preset balances token reduction with content quality preservation.
  #
  # @example Using a preset
  #   options = LlmDocsBuilder::CompressionPresets.conservative
  #   transformer = LlmDocsBuilder::MarkdownTransformer.new('README.md', options)
  #
  # @api public
  class CompressionPresets
    # Conservative compression (safest, 15-25% reduction)
    #
    # Only applies transformations that are very unlikely to affect quality:
    # - Removes frontmatter, comments, badges
    # - Normalizes whitespace
    # - Removes images (no value for text LLMs)
    #
    # @return [Hash] conservative compression options
    def self.conservative
      {
        remove_frontmatter: true,
        remove_comments: true,
        remove_badges: true,
        remove_images: true,
        normalize_whitespace: true
      }
    end

    # Moderate compression (balanced, 30-45% reduction)
    #
    # Adds more aggressive optimizations while preserving technical content:
    # - All conservative options
    # - Simplifies verbose link text
    # - Removes blockquote formatting
    # - Generates TOC for navigation
    #
    # @return [Hash] moderate compression options
    def self.moderate
      conservative.merge(
        simplify_links: true,
        remove_blockquotes: true,
        generate_toc: true
      )
    end

    # Aggressive compression (maximum reduction, 50-70% reduction)
    #
    # Applies all optimizations including potentially risky ones:
    # - All moderate options
    # - Removes code examples (may hurt technical docs)
    # - Removes duplicate paragraphs
    # - Removes stopwords (may affect readability)
    #
    # WARNING: May significantly alter content. Test carefully.
    #
    # @return [Hash] aggressive compression options
    def self.aggressive
      moderate.merge(
        remove_code_examples: true,
        remove_duplicates: true,
        remove_stopwords: true
      )
    end

    # Documentation-optimized compression (balanced for docs, 35-50% reduction)
    #
    # Optimized for technical documentation where code examples are important:
    # - All moderate options
    # - Removes duplicate content
    # - Keeps code examples intact
    # - Adds custom instruction for AI context
    #
    # @param custom_instruction [String] optional custom instruction text
    # @return [Hash] documentation compression options
    def self.documentation(custom_instruction: nil)
      moderate.merge(
        remove_duplicates: true,
        custom_instruction: custom_instruction || default_documentation_instruction
      )
    end

    # Tutorial-optimized compression (light compression, ~20% reduction)
    #
    # Optimized for tutorials and learning materials:
    # - Conservative options only
    # - Generates TOC
    # - Preserves all code examples and explanatory text
    # - Adds helpful custom instruction
    #
    # @return [Hash] tutorial compression options
    def self.tutorial
      conservative.merge(
        generate_toc: true,
        custom_instruction: 'This is a tutorial document with step-by-step instructions. '\
                           'Code examples and detailed explanations are preserved for learning purposes.'
      )
    end

    # API Reference compression (focused on structure, ~40% reduction)
    #
    # Optimized for API reference documentation:
    # - Removes narrative text aggressively
    # - Keeps code examples
    # - Generates TOC for quick navigation
    # - Simplifies verbose descriptions
    #
    # @return [Hash] API reference compression options
    def self.api_reference
      {
        remove_frontmatter: true,
        remove_comments: true,
        remove_badges: true,
        remove_images: true,
        remove_blockquotes: true,
        remove_duplicates: true,
        simplify_links: true,
        generate_toc: true,
        normalize_whitespace: true,
        custom_instruction: 'This is an API reference document. Focus on method signatures, '\
                           'parameters, return values, and code examples.'
      }
    end

    # Get preset by name
    #
    # @param name [Symbol] preset name (:conservative, :moderate, :aggressive, etc.)
    # @param custom_options [Hash] additional options to merge
    # @return [Hash] preset options merged with custom options
    def self.get(name, custom_options = {})
      preset = case name.to_sym
               when :conservative then conservative
               when :moderate then moderate
               when :aggressive then aggressive
               when :documentation then documentation
               when :tutorial then tutorial
               when :api_reference then api_reference
               else
                 raise ArgumentError, "Unknown preset: #{name}. "\
                                     'Available: :conservative, :moderate, :aggressive, '\
                                     ':documentation, :tutorial, :api_reference'
               end

      preset.merge(custom_options)
    end

    # Default custom instruction for documentation
    #
    # @return [String] default documentation instruction
    # @api private
    def self.default_documentation_instruction
      'This documentation has been optimized for AI consumption with reduced redundancy '\
      'while preserving all technical content and code examples.'
    end

    private_class_method :default_documentation_instruction
  end
end
