# frozen_string_literal: true

require 'zeitwerk'
require 'pathname'
require 'find'

loader = Zeitwerk::Loader.for_gem
loader.setup

module LlmsTxt
  # Standard exceptions hierarchy
  class Error < StandardError; end
  class GenerationError < Error; end
  class ValidationError < Error; end

  class << self
    # Generates llms.txt from existing markdown documentation
    #
    # @param docs_path [String] path to documentation directory or file
    # @param options [Hash] generation options
    # @option options [String] :base_url base URL for converting relative links
    # @option options [String] :title project title (auto-detected if not provided)
    # @option options [String] :description project description (auto-detected if not provided)
    # @option options [String] :output output file path (default: 'llms.txt')
    # @return [String] generated llms.txt content
    def generate_from_docs(docs_path, options = {})
      Generator.new(docs_path, options).generate
    end

    # Transforms a markdown file to be AI-friendly
    #
    # @param file_path [String] path to markdown file
    # @param options [Hash] transformation options
    # @option options [String] :base_url base URL for expanding relative links
    # @option options [Boolean] :convert_urls convert HTML URLs to markdown format
    # @return [String] transformed markdown content
    def transform_markdown(file_path, options = {})
      MarkdownTransformer.new(file_path, options).transform
    end

    # Parses an existing llms.txt file
    #
    # @param file_path [String] path to the llms.txt file to parse
    # @return [Parser] parsed llms.txt object
    def parse(file_path)
      Parser.new(file_path).parse
    end

    # Validates llms.txt content
    #
    # @param content [String] the llms.txt content to validate
    # @return [Boolean] true if content is valid, false otherwise
    def validate(content)
      Validator.new(content).valid?
    end
  end
end
