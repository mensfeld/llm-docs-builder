# frozen_string_literal: true

require 'fileutils'

module LlmDocsBuilder
  # Bulk transforms multiple markdown files to be AI-friendly
  #
  # Processes all markdown files in a directory recursively, creating LLM-friendly versions
  # alongside the originals. Supports exclusion patterns and maintains directory structure.
  #
  # @example Transform all files in a directory
  #   transformer = LlmDocsBuilder::BulkTransformer.new('./docs',
  #     base_url: 'https://myproject.io',
  #     suffix: '.llm'
  #   )
  #   transformer.transform_all
  #
  # @api public
  class BulkTransformer
    # @return [String] path to documentation directory
    attr_reader :docs_path

    # @return [Hash] transformation options
    attr_reader :options

    # Initialize a new bulk transformer
    #
    # @param docs_path [String] path to documentation directory
    # @param options [Hash] transformation options
    # @option options [String] :base_url base URL for expanding relative links
    # @option options [Boolean] :convert_urls convert HTML URLs to markdown format
    # @option options [String] :suffix suffix for transformed files (default: '.llm')
    # @option options [Array<String>] :excludes glob patterns for files to exclude
    # @option options [Boolean] :include_hidden include files in hidden directories
    # @option options [Boolean] :verbose enable verbose output
    def initialize(docs_path, options = {})
      @docs_path = docs_path
      @options = {
        suffix: '.llm',
        excludes: []
      }.merge(options)
    end

    # Transform all markdown files in the directory
    #
    # Recursively finds all markdown files, applies transformations,
    # and saves LLM-friendly versions with the specified suffix.
    #
    # @return [Array<String>] paths of transformed files
    def transform_all
      raise Errors::GenerationError, "Directory not found: #{docs_path}" unless File.directory?(docs_path)

      markdown_files = find_markdown_files
      transformed_files = []

      markdown_files.each do |file_path|
        puts "Transforming #{file_path}..." if options[:verbose]

        transformed_content = transform_file(file_path)
        output_path = generate_output_path(file_path)

        # Ensure output directory exists
        FileUtils.mkdir_p(File.dirname(output_path))

        File.write(output_path, transformed_content)
        transformed_files << output_path

        puts "  → #{output_path}" if options[:verbose]
      end

      transformed_files
    end

    private

    # Recursively scans the docs directory for markdown files
    #
    # See MarkdownFinder for the files it skips
    #
    # @return [Array<String>] sorted paths to markdown files
    def find_markdown_files
      MarkdownFinder.new(docs_path, options).files.sort
    end

    # Applies markdown transformations to a single file
    #
    # Creates MarkdownTransformer instance and delegates transformation. Passes the file's
    # path relative to the docs directory so relative links resolve from its own location.
    #
    # @param file_path [String] path to markdown file
    # @return [String] transformed content
    def transform_file(file_path)
      source_path = Pathname.new(file_path).relative_path_from(Pathname.new(docs_path)).to_s
      transformer = MarkdownTransformer.new(file_path, options.merge(source_path: source_path))
      transformer.transform
    end

    # Constructs output path by adding suffix before .md extension
    #
    # For example: README.md with suffix .llm becomes README.llm.md
    #
    # @param input_path [String] original file path
    # @return [String] path for transformed file
    def generate_output_path(input_path)
      dir = File.dirname(input_path)
      basename = File.basename(input_path, '.md')
      suffix = options[:suffix]

      File.join(dir, "#{basename}#{suffix}.md")
    end
  end
end
