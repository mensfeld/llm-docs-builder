# frozen_string_literal: true

require 'optparse'

module LlmDocsBuilder
  # Command-line interface for llms-txt gem
  #
  # Provides commands for generating, transforming, parsing, and validating llms.txt files.
  # All file paths must be specified using flags (-d/--docs) for consistency.
  #
  # @example Run the CLI
  #   LlmDocsBuilder::CLI.run(['generate', '--docs', './docs', '--output', 'llms.txt'])
  #
  # @api public
  class CLI
    # Run the CLI with given arguments
    #
    # @param argv [Array<String>] command-line arguments (defaults to ARGV)
    def self.run(argv = ARGV)
      new.run(argv)
    end

    # Execute CLI command with error handling
    #
    # Parses command-line arguments and delegates to appropriate command handler.
    # Handles all LlmDocsBuilder errors gracefully with user-friendly messages.
    #
    # @param argv [Array<String>] command-line arguments
    # @raise [SystemExit] exits with status 1 on error
    def run(argv)
      options = parse_options(argv)

      case options[:command]
      when 'generate', nil
        generate(options)
      when 'transform'
        transform(options)
      when 'bulk-transform'
        bulk_transform(options)
      when 'compare'
        compare(options)
      when 'parse'
        parse(options)
      when 'validate'
        validate(options)
      when 'version'
        show_version
      else
        puts "Unknown command: #{options[:command]}"
        puts "Run 'llm-docs-builder --help' for usage information"
        exit 1
      end
    rescue LlmDocsBuilder::Errors::BaseError => e
      puts "Error: #{e.message}"
      exit 1
    rescue StandardError => e
      puts "Unexpected error: #{e.message}"
      puts e.backtrace.join("\n") if options&.fetch(:verbose, false)
      exit 1
    end

    private

    # Parse command-line options using OptionParser
    #
    # Extracts command and options from argv. First non-flag argument is treated as command name.
    #
    # @param argv [Array<String>] command-line arguments
    # @return [Hash] parsed options including :command, :config, :docs, :output, :verbose
    def parse_options(argv)
      options = {
        command: argv.first&.match?(/^[a-z-]+$/) ? argv.shift : nil
      }

      OptionParser.new do |opts|
        opts.banner = "llm-docs-builder - Build and optimize documentation for LLMs\n\nUsage: llm-docs-builder [command] [options]\n\nFor advanced configuration (base_url, title, description, convert_urls), use a config file."

        opts.separator ''
        opts.separator 'Commands:'
        opts.separator '  generate       Generate llms.txt from documentation (default)'
        opts.separator '  transform      Transform a markdown file to be AI-friendly'
        opts.separator '  bulk-transform Transform all markdown files in directory'
        opts.separator '  compare        Compare content sizes to measure context savings'
        opts.separator '  parse          Parse existing llms.txt file'
        opts.separator '  validate       Validate llms.txt file'
        opts.separator '  version        Show version'

        opts.separator ''
        opts.separator 'Options:'

        opts.on('-c', '--config PATH', 'Configuration file path (default: llm-docs-builder.yml)') do |path|
          options[:config] = path
        end

        opts.on('-d', '--docs PATH', 'Path to documentation directory or file') do |path|
          options[:docs] = path
        end

        opts.on('-o', '--output PATH', 'Output file path') do |path|
          options[:output] = path
        end

        opts.on('-u', '--url URL', 'URL to fetch for comparison') do |url|
          options[:url] = url
        end

        opts.on('-f', '--file PATH', 'Local markdown file for comparison') do |path|
          options[:file] = path
        end

        opts.on('-v', '--verbose', 'Verbose output') do
          options[:verbose] = true
        end

        opts.on('-h', '--help', 'Show this message') do
          puts opts
          exit
        end

        opts.on('--version', 'Show version') do
          show_version
          exit
        end
      end.parse!(argv)

      options
    end

    # Generate llms.txt from documentation directory or file
    #
    # Loads configuration, merges with CLI options, generates llms.txt content,
    # and optionally validates the output.
    #
    # @param options [Hash] command options from parse_options
    # @option options [String] :config path to config file
    # @option options [String] :docs path to documentation
    # @option options [String] :output output file path
    # @option options [Boolean] :verbose enable verbose output
    # @raise [SystemExit] exits with status 1 if docs path not found
    def generate(options)
      # Load config and merge with CLI options
      config = LlmDocsBuilder::Config.new(options[:config])
      merged_options = config.merge_with_options(options)

      docs_path = merged_options[:docs]

      unless File.exist?(docs_path)
        puts "Documentation path not found: #{docs_path}"
        exit 1
      end

      puts "Generating llms.txt from #{docs_path}..." if merged_options[:verbose]

      content = LlmDocsBuilder.generate_from_docs(docs_path, merged_options)
      output_path = merged_options[:output]

      File.write(output_path, content)
      puts "Successfully generated #{output_path}"

      return unless merged_options[:verbose]

      validator = LlmDocsBuilder::Validator.new(content)
      if validator.valid?
        puts 'Valid llms.txt format'
      else
        puts 'Validation warnings:'
        validator.errors.each { |error| puts "  - #{error}" }
      end
    end

    # Transform markdown file to be AI-friendly
    #
    # Expands relative links to absolute URLs and optionally converts HTML URLs to markdown format.
    #
    # @param options [Hash] command options from parse_options
    # @option options [String] :config path to config file
    # @option options [String] :docs path to markdown file (required)
    # @option options [String] :output output file path
    # @option options [String] :base_url base URL for link expansion
    # @option options [Boolean] :convert_urls convert .html to .md
    # @option options [Boolean] :verbose enable verbose output
    # @raise [SystemExit] exits with status 1 if file not found or -d flag missing
    def transform(options)
      # Load config and merge with CLI options
      config = LlmDocsBuilder::Config.new(options[:config])
      merged_options = config.merge_with_options(options)

      file_path = merged_options[:docs]

      unless file_path
        puts 'File path required for transform command (use -d/--docs)'
        exit 1
      end

      unless File.exist?(file_path)
        puts "File not found: #{file_path}"
        exit 1
      end

      puts "Transforming #{file_path}..." if merged_options[:verbose]

      content = LlmDocsBuilder.transform_markdown(file_path, merged_options)

      if merged_options[:output] && merged_options[:output] != 'llms.txt'
        File.write(merged_options[:output], content)
        puts "Transformed content saved to #{merged_options[:output]}"
      else
        puts content
      end
    end

    # Transform all markdown files in directory recursively
    #
    # Creates AI-friendly versions of all markdown files with configurable suffix and exclusions.
    #
    # @param options [Hash] command options from parse_options
    # @option options [String] :config path to config file
    # @option options [String] :docs path to documentation directory (required)
    # @option options [String] :suffix suffix for transformed files (default: '.llm')
    # @option options [Array<String>] :excludes glob patterns to exclude
    # @option options [String] :base_url base URL for link expansion
    # @option options [Boolean] :convert_urls convert .html to .md
    # @option options [Boolean] :verbose enable verbose output
    # @raise [SystemExit] exits with status 1 if directory not found or transformation fails
    def bulk_transform(options)
      # Load config and merge with CLI options
      config = LlmDocsBuilder::Config.new(options[:config])
      merged_options = config.merge_with_options(options)

      docs_path = merged_options[:docs]

      unless File.exist?(docs_path)
        puts "Documentation path not found: #{docs_path}"
        exit 1
      end

      unless File.directory?(docs_path)
        puts "Path must be a directory for bulk transformation: #{docs_path}"
        exit 1
      end

      puts "Bulk transforming markdown files in #{docs_path}..." if merged_options[:verbose]
      puts "Using suffix: #{merged_options[:suffix]}" if merged_options[:verbose]
      if merged_options[:verbose] && !merged_options[:excludes].empty?
        puts "Excludes: #{merged_options[:excludes].join(', ')}"
      end

      begin
        transformed_files = LlmDocsBuilder.bulk_transform(docs_path, merged_options)

        if transformed_files.empty?
          puts 'No markdown files found to transform'
        else
          puts "Successfully transformed #{transformed_files.size} files:"
          # verbose mode already shows progress
          unless merged_options[:verbose]
            transformed_files.each do |file|
              puts "  #{file}"
            end
          end
        end
      rescue LlmDocsBuilder::Errors::BaseError => e
        puts "Error during bulk transformation: #{e.message}"
        exit 1
      end
    end

    # Parse existing llms.txt file and display information
    #
    # Reads and parses llms.txt file, displaying title, description, and links.
    # Defaults to 'llms.txt' in current directory if no file specified.
    #
    # @param options [Hash] command options from parse_options
    # @option options [String] :config path to config file
    # @option options [String] :docs path to llms.txt file (defaults to 'llms.txt')
    # @option options [Boolean] :verbose enable verbose output with link counts
    # @raise [SystemExit] exits with status 1 if file not found
    def parse(options)
      # Load config and merge with CLI options
      config = LlmDocsBuilder::Config.new(options[:config])
      merged_options = config.merge_with_options(options)

      file_path = merged_options[:docs] || 'llms.txt'

      unless File.exist?(file_path)
        puts "File not found: #{file_path}"
        exit 1
      end

      parsed = LlmDocsBuilder.parse(file_path)

      if options[:verbose]
        puts "Title: #{parsed.title}"
        puts "Description: #{parsed.description}"
        puts "Documentation Links: #{parsed.documentation_links.size}"
        puts "Example Links: #{parsed.example_links.size}" if parsed.respond_to?(:example_links)
        puts "Optional Links: #{parsed.optional_links.size}" if parsed.respond_to?(:optional_links)
      end
    end

    # Compare content sizes between human and AI versions
    #
    # Measures context window savings by comparing:
    # - Remote URL with different User-Agents (human vs AI bot)
    # - Remote URL with local markdown file
    #
    # @param options [Hash] command options from parse_options
    # @option options [String] :url URL to fetch for comparison (required)
    # @option options [String] :file local markdown file for comparison (optional)
    # @option options [Boolean] :verbose enable verbose output
    # @raise [SystemExit] exits with status 1 if URL not provided or fetch fails
    def compare(options)
      url = options[:url]

      unless url
        puts 'URL required for compare command (use -u/--url)'
        puts ''
        puts 'Examples:'
        puts '  # Compare remote versions (different User-Agents)'
        puts '  llm-docs-builder compare --url https://example.com/docs/page.html'
        puts ''
        puts '  # Compare remote with local file'
        puts '  llm-docs-builder compare --url https://example.com/docs/page.html --file docs/page.md'
        exit 1
      end

      comparator_options = {
        local_file: options[:file],
        verbose: options[:verbose]
      }

      comparator = LlmDocsBuilder::Comparator.new(url, comparator_options)

      begin
        result = comparator.compare
        OutputFormatter.display_comparison_results(result)
      rescue LlmDocsBuilder::Errors::BaseError => e
        puts "Error during comparison: #{e.message}"
        exit 1
      end
    end

    # Validate llms.txt file format
    #
    # Checks if llms.txt file follows proper format with title, description, and documentation links.
    # Defaults to 'llms.txt' in current directory if no file specified.
    #
    # @param options [Hash] command options from parse_options
    # @option options [String] :config path to config file
    # @option options [String] :docs path to llms.txt file (defaults to 'llms.txt')
    # @raise [SystemExit] exits with status 1 if file not found or invalid
    def validate(options)
      # Load config and merge with CLI options
      config = LlmDocsBuilder::Config.new(options[:config])
      merged_options = config.merge_with_options(options)

      file_path = merged_options[:docs] || 'llms.txt'

      unless File.exist?(file_path)
        puts "File not found: #{file_path}"
        exit 1
      end

      content = File.read(file_path)
      valid = LlmDocsBuilder.validate(content)

      if valid
        puts 'Valid llms.txt file'
      else
        puts 'Invalid llms.txt file'
        puts "\nErrors:"
        LlmDocsBuilder::Validator.new(content).errors.each do |error|
          puts "  - #{error}"
        end
        exit 1
      end
    end

    # Display version information
    #
    def show_version
      puts "llm-docs-builder version #{LlmDocsBuilder::VERSION}"
    end
  end
end
