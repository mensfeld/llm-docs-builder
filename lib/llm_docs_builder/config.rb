# frozen_string_literal: true

require 'yaml'

module LlmDocsBuilder
  # Simple configuration loader for llm-docs-builder.yml files
  #
  # Loads YAML configuration files and provides a simple interface for accessing configuration
  # values. Automatically looks for config files in the current directory if none specified.
  #
  # @example Load default config file
  #   config = LlmDocsBuilder::Config.new
  #
  # @example Load specific config file
  #   config = LlmDocsBuilder::Config.new('my-config.yml')
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
    # @option options [String] :docs path to documentation directory or file
    # @option options [String] :base_url base URL for expanding relative links
    # @option options [String] :title project title
    # @option options [String] :description project description
    # @option options [String] :body additional body content
    # @option options [String] :output output file path
    # @option options [Boolean] :convert_urls convert HTML URLs to markdown format
    # @option options [Boolean] :remove_comments remove HTML comments
    # @option options [Boolean] :normalize_whitespace normalize whitespace
    # @option options [Boolean] :remove_badges remove badge images
    # @option options [Boolean] :remove_frontmatter remove YAML/TOML frontmatter
    # @option options [Boolean] :verbose enable verbose output
    # @option options [String] :suffix suffix for transformed files
    # @option options [Array<String>] :excludes glob patterns for files to exclude
    # @option options [Boolean] :bulk enable bulk transformation mode
    # @option options [Boolean] :include_hidden include hidden files
    # @option options [Boolean] :remove_code_examples remove code blocks
    # @option options [Boolean] :remove_images remove image syntax
    # @option options [Boolean] :simplify_links simplify link text
    # @option options [Boolean] :remove_blockquotes remove blockquote formatting
    # @option options [Boolean] :generate_toc generate table of contents
    # @option options [String] :custom_instruction custom instruction text
    # @option options [Boolean] :remove_stopwords remove common stopwords
    # @option options [Boolean] :remove_duplicates remove duplicate paragraphs
    # @option options [Boolean] :normalize_headings normalize heading hierarchy
    # @option options [String] :heading_separator separator for heading paths
    # @option options [Boolean] :include_metadata include metadata in output
    # @option options [Boolean] :include_tokens include token counts
    # @option options [Boolean] :include_timestamps include timestamps
    # @option options [Boolean] :include_priority include priority metadata
    # @option options [Boolean] :calculate_compression calculate compression ratios
    # @option options [String] :content raw markdown content
    # @option options [String] :source_url source URL for content
    # @return [Hash] merged configuration with CLI overrides applied
    def merge_with_options(options)
      # CLI options override config file, config file provides defaults
      {
        docs: if options.key?(:docs)
                options[:docs]
              else
                self['docs'] || '.'
              end,
        base_url: options[:base_url] || self['base_url'],
        title: options[:title] || self['title'],
        description: options[:description] || self['description'],
        body: options[:body] || self['body'],
        output: options[:output] || self['output'] || 'llms.txt',
        convert_urls: if options.key?(:convert_urls)
                        options[:convert_urls]
                      else
                        self['convert_urls'] || false
                      end,
        remove_comments: if options.key?(:remove_comments)
                           options[:remove_comments]
                         elsif !self['remove_comments'].nil?
                           self['remove_comments']
                         else
                           true
                         end,
        normalize_whitespace: if options.key?(:normalize_whitespace)
                                options[:normalize_whitespace]
                              elsif !self['normalize_whitespace'].nil?
                                self['normalize_whitespace']
                              else
                                true
                              end,
        remove_badges: if options.key?(:remove_badges)
                         options[:remove_badges]
                       elsif !self['remove_badges'].nil?
                         self['remove_badges']
                       else
                         true
                       end,
        remove_frontmatter: if options.key?(:remove_frontmatter)
                              options[:remove_frontmatter]
                            elsif !self['remove_frontmatter'].nil?
                              self['remove_frontmatter']
                            else
                              true
                            end,
        verbose: options.key?(:verbose) ? options[:verbose] : (self['verbose'] || false),
        # Bulk transformation options
        suffix: options[:suffix] || self['suffix'] || '.llm',
        excludes: options[:excludes] || self['excludes'] || [],
        bulk: options.key?(:bulk) ? options[:bulk] : (self['bulk'] || false),
        include_hidden: options.key?(:include_hidden) ? options[:include_hidden] : (self['include_hidden'] || false),
        # New compression options
        remove_code_examples: if options.key?(:remove_code_examples)
                                options[:remove_code_examples]
                              else
                                self['remove_code_examples'] || false
                              end,
        remove_images: if options.key?(:remove_images)
                         options[:remove_images]
                       else
                         self['remove_images'] || false
                       end,
        simplify_links: if options.key?(:simplify_links)
                          options[:simplify_links]
                        else
                          self['simplify_links'] || false
                        end,
        remove_blockquotes: if options.key?(:remove_blockquotes)
                              options[:remove_blockquotes]
                            else
                              self['remove_blockquotes'] || false
                            end,
        generate_toc: if options.key?(:generate_toc)
                        options[:generate_toc]
                      else
                        self['generate_toc'] || false
                      end,
        custom_instruction: options[:custom_instruction] || self['custom_instruction'],
        remove_stopwords: if options.key?(:remove_stopwords)
                            options[:remove_stopwords]
                          else
                            self['remove_stopwords'] || false
                          end,
        remove_duplicates: if options.key?(:remove_duplicates)
                             options[:remove_duplicates]
                           else
                             self['remove_duplicates'] || false
                           end,
        # New RAG enhancement options
        normalize_headings: if options.key?(:normalize_headings)
                              options[:normalize_headings]
                            else
                              self['normalize_headings'] || false
                            end,
        heading_separator: options[:heading_separator] || self['heading_separator'] || ' / ',
        include_metadata: if options.key?(:include_metadata)
                            options[:include_metadata]
                          else
                            self['include_metadata'] || false
                          end,
        include_tokens: if options.key?(:include_tokens)
                          options[:include_tokens]
                        else
                          self['include_tokens'] || false
                        end,
        include_timestamps: if options.key?(:include_timestamps)
                              options[:include_timestamps]
                            else
                              self['include_timestamps'] || false
                            end,
        include_priority: if options.key?(:include_priority)
                            options[:include_priority]
                          else
                            self['include_priority'] || false
                          end,
        calculate_compression: if options.key?(:calculate_compression)
                                 options[:calculate_compression]
                               else
                                 self['calculate_compression'] || false
                               end
      }.tap do |merged|
        merged[:content] = options[:content] if options.key?(:content)
        merged[:source_url] = options[:source_url] if options.key?(:source_url)
      end
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
    # 1. llm-docs-builder.yml
    # 2. llm-docs-builder.yaml
    # 3. .llm-docs-builder.yml
    #
    # @return [String, nil] path to config file or nil if none found
    def find_config_file
      candidates = ['llm-docs-builder.yml', 'llm-docs-builder.yaml', '.llm-docs-builder.yml']
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
