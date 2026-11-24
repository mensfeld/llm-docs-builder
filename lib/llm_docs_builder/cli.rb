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
        exit_with_usage_error("Unknown command: #{options[:command]}")
      end
    rescue OptionParser::ParseError => e
      exit_with_usage_error("Error: #{e.message}")
    rescue LlmDocsBuilder::Errors::BaseError => e
      exit_with_error("Error: #{e.message}")
    rescue StandardError => e
      lines = ["Unexpected error: #{e.message}"]
      lines << e.backtrace.join("\n") if options&.fetch(:verbose, false)
      exit_with_error(*lines)
    end

    private

    # Print error lines to stderr and exit
    #
    # Uses $stderr directly because Kernel#warn prints nothing when warnings are disabled (-W0).
    #
    # @param lines [Array<String>] lines to print
    # @raise [SystemExit] always, with status 1
    def exit_with_error(*lines)
      lines.each { |line| $stderr.puts(line) }
      exit 1
    end

    # Print a usage error with a pointer to the help and exit
    #
    # @param message [String] error message
    # @raise [SystemExit] always, with status 1
    def exit_with_usage_error(message)
      exit_with_error(message, "Run 'llm-docs-builder --help' for usage information")
    end

    # Parse command-line options using OptionParser
    #
    # Extracts command and options from argv. First non-flag argument is treated as command name.
    #
    # @param argv [Array<String>] command-line arguments
    # @return [Hash] parsed options including :command, :config, :docs, :output, :verbose
    def parse_options(argv)
      command_token = argv.first
      options = {
        command: command_token&.match?(/\A[a-z](?:[a-z-]*[a-z])?\z/) ? argv.shift : nil
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

        opts.on('-u', '--url URL', 'URL to fetch for transform or comparison') do |url|
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
    # Loads configuration, merges with CLI options, generates llms.txt content, and optionally validates the output.
    #
    # @param options [Hash] command options from parse_options
    # @option options [String] :config path to config file
    # @option options [String] :docs path to documentation
    # @option options [String] :output output file path
    # @option options [Boolean] :verbose enable verbose output
    # @raise [SystemExit] exits with status 1 if docs path not found
    def generate(options)
      # Load config and merge with CLI options
      config = load_config(options[:config])
      merged_options = config.merge_with_options(options)

      docs_path = merged_options[:docs]

      exit_with_error("Documentation path not found: #{docs_path}") unless File.exist?(docs_path)

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
      config = load_config(options[:config])
      merged_options = config.merge_with_options(options)

      url = options[:url]
      cli_file_path = options[:docs]
      config_file_path = config['docs']
      file_path = url ? cli_file_path : (cli_file_path || config_file_path)

      exit_with_error('Cannot use both --docs and --url for transform command') if url && cli_file_path

      unless file_path
        exit_with_error('File path required for transform command (use -d/--docs)') unless url
      end

      content =
        if url
          puts "Fetching #{url}..." if merged_options[:verbose]
          fetcher = LlmDocsBuilder::UrlFetcher.new(verbose: merged_options[:verbose])
          remote_content = fetcher.fetch(url)
          puts "Transforming content from #{url}..." if merged_options[:verbose]
          transform_options = merged_options.merge(content: remote_content, docs: nil, source_url: url)
          LlmDocsBuilder.transform_markdown(nil, transform_options)
        else
          exit_with_error("File not found: #{file_path}") unless File.exist?(file_path)

          puts "Transforming #{file_path}..." if merged_options[:verbose]

          merged_options[:docs] = file_path
          LlmDocsBuilder.transform_markdown(file_path, merged_options)
        end

      if merged_options[:output] && merged_options[:output] != 'llms.txt'
        File.write(merged_options[:output], content.sub(/\n?\z/, "\n"))
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
      config = load_config(options[:config])
      merged_options = config.merge_with_options(options)

      docs_path = merged_options[:docs]

      exit_with_error("Documentation path not found: #{docs_path}") unless File.exist?(docs_path)

      unless File.directory?(docs_path)
        exit_with_error("Path must be a directory for bulk transformation: #{docs_path}")
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
        exit_with_error("Error during bulk transformation: #{e.message}")
      end
    end

    # Parse existing llms.txt file and display information
    #
    # Reads and parses llms.txt file, displaying title, description, and links.
    # Defaults to 'llms.txt' in current directory if no file specified.
    # The config file's docs setting is the docs directory for generate, so it is not used here.
    #
    # @param options [Hash] command options from parse_options
    # @option options [String] :docs path to llms.txt file (defaults to 'llms.txt')
    # @option options [Boolean] :verbose also list each link under its section count
    # @raise [SystemExit] exits with status 1 if file not found
    def parse(options)
      file_path = options[:docs] || 'llms.txt'

      exit_with_error("File not found: #{file_path}") unless File.exist?(file_path)

      parsed = LlmDocsBuilder.parse(file_path)

      puts "Title: #{parsed.title}"
      puts "Description: #{parsed.description}"

      {
        'Documentation' => parsed.documentation_links,
        'Example' => parsed.example_links,
        'Optional' => parsed.optional_links
      }.each do |section, links|
        puts "#{section} Links: #{links.size}"
        next unless options[:verbose]

        links.each { |link| puts "  - #{link[:title]}: #{link[:url]}" }
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
        exit_with_error(
          'URL required for compare command (use -u/--url)',
          '',
          'Examples:',
          '  # Compare remote versions (different User-Agents)',
          '  llm-docs-builder compare --url https://example.com/docs/page.html',
          '',
          '  # Compare remote with local file',
          '  llm-docs-builder compare --url https://example.com/docs/page.html --file docs/page.md'
        )
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
        exit_with_error("Error during comparison: #{e.message}")
      end
    end

    # Validate llms.txt file format
    #
    # Checks if llms.txt file follows proper format with title, description, and documentation links.
    # Defaults to 'llms.txt' in current directory if no file specified.
    # The config file's docs setting is the docs directory for generate, so it is not used here.
    #
    # @param options [Hash] command options from parse_options
    # @option options [String] :docs path to llms.txt file (defaults to 'llms.txt')
    # @raise [SystemExit] exits with status 1 if file not found or invalid
    def validate(options)
      file_path = options[:docs] || 'llms.txt'

      exit_with_error("File not found: #{file_path}") unless File.exist?(file_path)

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

    # Load the config file given with --config, or the auto-discovered one
    #
    # @param config_path [String, nil] path given with --config, or nil to auto-find
    # @return [LlmDocsBuilder::Config] loaded configuration
    # @raise [LlmDocsBuilder::Errors::GenerationError] if the given config file does not exist
    def load_config(config_path)
      if config_path && !File.exist?(config_path)
        raise LlmDocsBuilder::Errors::GenerationError, "Config file not found: #{config_path}"
      end

      LlmDocsBuilder::Config.new(config_path)
    end

    # Display version information
    def show_version
      puts "llm-docs-builder version #{LlmDocsBuilder::VERSION}"
    end
  end
end
