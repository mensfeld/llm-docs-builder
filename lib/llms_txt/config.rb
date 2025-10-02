# frozen_string_literal: true

require 'yaml'

module LlmsTxt
  # Simple configuration loader for llms-txt.yml files
  #
  # Loads YAML configuration files and provides a simple interface for accessing configuration
  # values. Automatically looks for config files in the current directory if none specified.
  #
  # @example Load default config file
  #   config = LlmsTxt::Config.new
  #
  # @example Load specific config file
  #   config = LlmsTxt::Config.new('my-config.yml')
  #
  # @example Access config values
  #   config['base_url']        # => "https://myproject.io"
  #   config.dig('output')      # => "llms.txt"
  #
  # @api public
  class Config
    # @return [Hash] the loaded configuration data
    attr_reader :data

    # Initialize a new configuration loader
    #
    # @param config_file [String, nil] path to YAML config file, or nil to auto-find
    def initialize(config_file = nil)
      @config_file = config_file || find_config_file
      @data = load_config
    end

    # Access configuration value by key
    #
    # @param key [String, Symbol] configuration key
    # @return [Object, nil] configuration value or nil if not found
    def [](key)
      data[key.to_s]
    end

    # Access nested configuration values
    #
    # @param keys [Array<String, Symbol>] nested keys to access
    # @return [Object, nil] configuration value or nil if not found
    def dig(*keys)
      data.dig(*keys.map(&:to_s))
    end

    # Merge config file values with CLI options
    #
    # CLI options take precedence over config file values. Config file provides
    # defaults for any options not specified via CLI.
    #
    # @param options [Hash] CLI options hash
    # @return [Hash] merged configuration with CLI overrides applied
    def merge_with_options(options)
      # CLI options override config file, config file provides defaults
      {
        docs: options[:docs] || self['docs'] || '.',
        base_url: options[:base_url] || self['base_url'],
        title: options[:title] || self['title'],
        description: options[:description] || self['description'],
        output: options[:output] || self['output'] || 'llms.txt',
        convert_urls: options.key?(:convert_urls) ?
          options[:convert_urls] : (self['convert_urls'] || false),
        verbose: options.key?(:verbose) ? options[:verbose] : (self['verbose'] || false),
        # Bulk transformation options
        suffix: options[:suffix] || self['suffix'] || '.llm',
        excludes: options[:excludes] || self['excludes'] || [],
        bulk: options.key?(:bulk) ? options[:bulk] : (self['bulk'] || false)
      }
    end

    # Check if a config file was found and exists
    #
    # @return [Boolean] true if config file exists, false otherwise
    def exists?
      @config_file && File.exist?(@config_file)
    end

    private

    # Find config file in current directory
    #
    # Looks for config files in order of preference:
    # 1. llms-txt.yml
    # 2. llms-txt.yaml
    # 3. .llms-txt.yml
    #
    # @return [String, nil] path to config file or nil if none found
    def find_config_file
      candidates = ['llms-txt.yml', 'llms-txt.yaml', '.llms-txt.yml']
      candidates.find { |file| File.exist?(file) }
    end

    # Load and parse YAML config file
    #
    # @return [Hash] parsed config data, empty hash if no file
    # @raise [Errors::GenerationError] if YAML is invalid or file cannot be read
    def load_config
      return {} unless @config_file && File.exist?(@config_file)

      begin
        YAML.load_file(@config_file) || {}
      rescue Psych::SyntaxError => e
        raise Errors::GenerationError, "Invalid YAML in config file #{@config_file}: #{e.message}"
      rescue StandardError => e
        raise Errors::GenerationError, "Failed to load config file #{@config_file}: #{e.message}"
      end
    end
  end
end
