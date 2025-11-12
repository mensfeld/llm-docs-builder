# frozen_string_literal: true

require 'zeitwerk'
require 'pathname'
require 'find'

autoload(:Nokogiri, 'nokogiri')
autoload(:CGI, 'cgi')

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect('cli' => 'CLI')
loader.setup

module LlmDocsBuilder
  class << self
    # Generates llms.txt from existing markdown documentation
    #
    # @param docs_path [String, nil] path to documentation directory or file (optional if
    #   config_file provided)
    # @param options [Hash] generation options
    # @option options [String] :config_file path to YAML config file (auto-finds llm-docs-builder.yml)
    # @option options [String] :base_url base URL for converting relative links (overrides config)
    # @option options [String] :title project title (auto-detected if not provided, overrides
    #   config)
    # @option options [String] :description project description (auto-detected if not provided,
    #   overrides config)
    # @option options [String] :output output file path (default: 'llms.txt', overrides config)
    # @option options [Boolean] :convert_urls convert HTML URLs to markdown format (overrides
    #   config)
    # @option options [Boolean] :verbose enable verbose output (overrides config)
    # @option options [String] :content raw markdown content (used for remote sources)
    # @return [String] generated llms.txt content
    #
    # @example Generate from docs directory
    #   LlmDocsBuilder.generate_from_docs('./docs')
    #
    # @example Generate using config file
    #   LlmDocsBuilder.generate_from_docs(config_file: 'llm-docs-builder.yml')
    #
    # @example Generate with config file and overrides
    #   LlmDocsBuilder.generate_from_docs('./docs',
    #     config_file: 'my-config.yml',
    #     title: 'Override Title'
    #   )
    def generate_from_docs(docs_path = nil, options = {})
      # Support config-first usage: generate_from_docs(config_file: 'path.yml')
      if docs_path.is_a?(Hash) && docs_path.key?(:config_file)
        options = docs_path
        docs_path = nil
      end

      config = Config.new(options[:config_file])
      merged_options = config.merge_with_options(options)

      # Use docs_path param or config file docs setting
      final_docs_path = docs_path || merged_options[:docs]

      Generator.new(final_docs_path, merged_options).generate
    end

    # Transforms a markdown file to be AI-friendly
    #
    # @param file_path [String] path to markdown file
    # @param options [Hash] transformation options
    # @option options [String] :config_file path to YAML config file (auto-finds llm-docs-builder.yml)
    # @option options [String] :base_url base URL for expanding relative links (overrides config)
    # @option options [Boolean] :convert_urls convert HTML URLs to markdown format (overrides
    #   config)
    # @option options [Boolean] :verbose enable verbose output (overrides config)
    # @return [String] transformed markdown content
    #
    # @example Transform with direct options
    #   LlmDocsBuilder.transform_markdown('README.md',
    #     base_url: 'https://myproject.io',
    #     convert_urls: true
    #   )
    #
    # @example Transform using config file
    #   LlmDocsBuilder.transform_markdown('README.md', config_file: 'llm-docs-builder.yml')
    def transform_markdown(file_path, options = {})
      config = Config.new(options[:config_file])
      merged_options = config.merge_with_options(options)

      MarkdownTransformer.new(file_path, merged_options).transform
    end

    # Bulk transforms multiple markdown files to be AI-friendly
    #
    # @param docs_path [String] path to documentation directory
    # @param options [Hash] transformation options
    # @option options [String] :config_file path to YAML config file (auto-finds llm-docs-builder.yml)
    # @option options [String] :base_url base URL for expanding relative links (overrides config)
    # @option options [Boolean] :convert_urls convert HTML URLs to markdown format (overrides
    #   config)
    # @option options [String] :suffix suffix for transformed files (default: '.llm', overrides
    #   config)
    # @option options [Array<String>] :excludes glob patterns for files to exclude (overrides
    #   config)
    # @option options [Boolean] :verbose enable verbose output (overrides config)
    # @return [Array<String>] paths of transformed files
    #
    # @example Bulk transform with direct options
    #   LlmDocsBuilder.bulk_transform('./docs',
    #     base_url: 'https://myproject.io',
    #     suffix: '.ai',
    #     excludes: ['**/private/**', 'draft-*.md']
    #   )
    #
    # @example Bulk transform using config file
    #   LlmDocsBuilder.bulk_transform('./docs', config_file: 'llm-docs-builder.yml')
    def bulk_transform(docs_path, options = {})
      config = Config.new(options[:config_file])
      merged_options = config.merge_with_options(options)

      BulkTransformer.new(docs_path, merged_options).transform_all
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
