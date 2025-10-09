# frozen_string_literal: true

module LlmDocsBuilder
  # Namespace used to encapsulate all the internal errors of LlmDocsBuilder
  module Errors
    # Base class for all the LlmDocsBuilder internal errors
    BaseError = Class.new(StandardError)

    # Raised when llms.txt generation fails due to configuration issues,
    # missing directories, invalid YAML, or file access problems
    #
    # @example When directory doesn't exist
    #   LlmDocsBuilder.bulk_transform('/nonexistent/path')
    #   # => raises GenerationError: "Directory not found: /nonexistent/path"
    #
    # @example When config YAML is invalid
    #   LlmDocsBuilder.generate_from_docs(config_file: 'invalid.yml')
    #   # => raises GenerationError: "Invalid YAML in config file..."
    GenerationError = Class.new(BaseError)

    # Raised when llms.txt content validation fails
    #
    # This error is intended for validation failures but currently not used.
    # The Validator class returns boolean results instead of raising errors.
    #
    # @example Future usage (when validation raises)
    #   LlmDocsBuilder.validate!(invalid_content)
    #   # => raises ValidationError: "Missing required H1 title"
    ValidationError = Class.new(BaseError)
  end
end
