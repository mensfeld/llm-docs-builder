# frozen_string_literal: true

require 'optparse'

module LlmsTxt
  # Command-line interface for llms-txt gem
  #
  # Provides commands for generating, transforming, parsing, and validating llms.txt files.
  # All file paths must be specified using flags (-d/--docs) for consistency.
  #
  # @example Run the CLI
  #   LlmsTxt::CLI.run(['generate', '--docs', './docs', '--output', 'llms.txt'])
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
    # Handles all LlmsTxt errors gracefully with user-friendly messages.
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
      when 'parse'
        parse(options)
      when 'validate'
        validate(options)
      when 'version'
        show_version
      else
        puts "Unknown command: #{options[:command]}"
        puts "Run 'llms-txt --help' for usage information"
        exit 1
      end
    rescue LlmsTxt::Errors::BaseError => e
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
        opts.banner = "llms-txt - Simple tool for generating llms.txt from markdown documentation\n\nUsage: llms-txt [command] [options]\n\nFor advanced configuration (base_url, title, description, convert_urls), use a config file."

        opts.separator ''
        opts.separator 'Commands:'
        opts.separator '  generate       Generate llms.txt from documentation (default)'
        opts.separator '  transform      Transform a markdown file to be AI-friendly'
        opts.separator '  bulk-transform Transform all markdown files in directory'
        opts.separator '  parse          Parse existing llms.txt file'
        opts.separator '  validate       Validate llms.txt file'
        opts.separator '  version        Show version'

        opts.separator ''
        opts.separator 'Options:'

        opts.on('-c', '--config PATH', 'Configuration file path (default: llms-txt.yml)') do |path|
          options[:config] = path
        end

        opts.on('-d', '--docs PATH', 'Path to documentation directory or file') do |path|
          options[:docs] = path
        end

        opts.on('-o', '--output PATH', 'Output file path') do |path|
          options[:output] = path
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
      config = LlmsTxt::Config.new(options[:config])
      merged_options = config.merge_with_options(options)

      docs_path = merged_options[:docs]

      unless File.exist?(docs_path)
        puts "Documentation path not found: #{docs_path}"
        exit 1
      end

      puts "Generating llms.txt from #{docs_path}..." if merged_options[:verbose]

      content = LlmsTxt.generate_from_docs(docs_path, merged_options)
      output_path = merged_options[:output]

      File.write(output_path, content)
      puts "Successfully generated #{output_path}"

      return unless merged_options[:verbose]

      validator = LlmsTxt::Validator.new(content)
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
      config = LlmsTxt::Config.new(options[:config])
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

      content = LlmsTxt.transform_markdown(file_path, merged_options)

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
      config = LlmsTxt::Config.new(options[:config])
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
        transformed_files = LlmsTxt.bulk_transform(docs_path, merged_options)

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
      rescue LlmsTxt::Errors::BaseError => e
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
      config = LlmsTxt::Config.new(options[:config])
      merged_options = config.merge_with_options(options)

      file_path = merged_options[:docs] || 'llms.txt'

      unless File.exist?(file_path)
        puts "File not found: #{file_path}"
        exit 1
      end

      parsed = LlmsTxt.parse(file_path)

      if options[:verbose]
        puts "Title: #{parsed.title}"
        puts "Description: #{parsed.description}"
        puts "Documentation Links: #{parsed.documentation_links.size}"
        puts "Example Links: #{parsed.example_links.size}" if parsed.respond_to?(:example_links)
        puts "Optional Links: #{parsed.optional_links.size}" if parsed.respond_to?(:optional_links)
      elsif parsed.respond_to?(:to_xml)
        puts parsed.to_xml
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
      config = LlmsTxt::Config.new(options[:config])
      merged_options = config.merge_with_options(options)

      file_path = merged_options[:docs] || 'llms.txt'

      unless File.exist?(file_path)
        puts "File not found: #{file_path}"
        exit 1
      end

      content = File.read(file_path)
      valid = LlmsTxt.validate(content)

      if valid
        puts 'Valid llms.txt file'
      else
        puts 'Invalid llms.txt file'
        puts "\nErrors:"
        LlmsTxt::Validator.new(content).errors.each do |error|
          puts "  - #{error}"
        end
        exit 1
      end
    end

    # Display version information
    #
    def show_version
      puts "llms-txt version #{LlmsTxt::VERSION}"
    end
  end
end
