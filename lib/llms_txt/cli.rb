# frozen_string_literal: true

require 'optparse'

module LlmsTxt
  class CLI
    def self.run(argv = ARGV)
      new.run(argv)
    end

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

      options[:file_path] = argv.first if argv.any?
      options
    end

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

      if merged_options[:verbose]
        validator = LlmsTxt::Validator.new(content)
        if validator.valid?
          puts "Valid llms.txt format"
        else
          puts "Validation warnings:"
          validator.errors.each { |error| puts "  - #{error}" }
        end
      end
    end

    def transform(options)
      # Load config and merge with CLI options
      config = LlmsTxt::Config.new(options[:config])
      merged_options = config.merge_with_options(options)

      file_path = options[:file_path]

      unless file_path
        puts "File path required for transform command"
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
      puts "Excludes: #{merged_options[:excludes].join(', ')}" if merged_options[:verbose] && !merged_options[:excludes].empty?

      begin
        transformed_files = LlmsTxt.bulk_transform(docs_path, merged_options)

        if transformed_files.empty?
          puts "No markdown files found to transform"
        else
          puts "Successfully transformed #{transformed_files.size} files:"
          transformed_files.each { |file| puts "  #{file}" } unless merged_options[:verbose] # verbose mode already shows progress
        end
      rescue LlmsTxt::Errors::BaseError => e
        puts "Error during bulk transformation: #{e.message}"
        exit 1
      end
    end

    def parse(options)
      file_path = options[:file_path] || 'llms.txt'

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
      else
        puts parsed.to_xml if parsed.respond_to?(:to_xml)
      end
    end

    def validate(options)
      file_path = options[:file_path] || 'llms.txt'

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

    def show_version
      puts "llms-txt version #{LlmsTxt::VERSION}"
    end
  end
end
