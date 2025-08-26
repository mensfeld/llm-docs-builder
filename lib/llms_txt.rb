# frozen_string_literal: true

require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.setup

module LlmsTxt
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class GenerationError < Error; end
  class ValidationError < Error; end

  class << self
    attr_writer :configuration

    # Returns the current configuration object
    #
    # @return [Configuration] the current configuration instance
    # @example
    #   config = LlmsTxt.configuration
    #   config.llm_provider = :claude
    def configuration
      @configuration ||= Configuration.new
    end

    # Configures the LlmsTxt gem with the provided settings
    #
    # @yield [config] configuration block
    # @yieldparam config [Configuration] the configuration object to modify
    # @return [void]
    #
    # @example Configure with Claude AI
    #   LlmsTxt.configure do |config|
    #     config.llm_provider = :claude
    #     config.api_key = ENV['ANTHROPIC_API_KEY']
    #     config.verbose = true
    #   end
    def configure
      yield(configuration)
    end

    # Generates an llms.txt file for a Ruby project
    #
    # @param options [Hash] generation options
    # @option options [String] :project_root the project root directory
    # @option options [String] :output output file path
    # @option options [Boolean] :no_llm use template mode without LLM
    # @option options [String] :expand_links base URL for expanding relative links
    # @option options [Boolean] :convert_urls convert HTML URLs to markdown format
    # @option options [Boolean] :include_optional include optional sections
    #
    # @return [String] the generated llms.txt content
    #
    # @example Generate with AI
    #   content = LlmsTxt.generate
    #
    # @example Generate without AI (template mode)
    #   content = LlmsTxt.generate(no_llm: true)
    #
    # @example Generate with link processing
    #   content = LlmsTxt.generate(
    #     expand_links: 'https://myproject.io',
    #     convert_urls: true
    #   )
    def generate(options = {})
      Generator.new(options).generate
    end

    # Parses an existing llms.txt file
    #
    # @param file_path [String] path to the llms.txt file to parse
    # @return [Parser] parsed llms.txt object with title, description, and links
    # @raise [Error] if the file cannot be read or parsed
    #
    # @example Parse a file
    #   parsed = LlmsTxt.parse('llms.txt')
    #   puts parsed.title
    #   puts parsed.description
    #   puts parsed.documentation_links.map(&:url)
    def parse(file_path)
      Parser.new(file_path).parse
    end

    # Validates llms.txt content against the specification
    #
    # @param content [String] the llms.txt content to validate
    # @return [Boolean] true if content is valid, false otherwise
    #
    # @example Validate content
    #   content = File.read('llms.txt')
    #   if LlmsTxt.validate(content)
    #     puts "Valid llms.txt file"
    #   else
    #     puts "Invalid format"
    #   end
    def validate(content)
      Validator.new(content).valid?
    end

    # Creates a new DSL builder for composing llms.txt content
    #
    # @yield [builder] DSL builder block
    # @yieldparam builder [Builders::DslBuilder] the DSL builder instance
    # @return [Builders::DslBuilder] the configured builder
    #
    # @example Build with DSL
    #   content = LlmsTxt.build do |llms|
    #     llms.title 'My Gem'
    #     llms.description 'A Ruby library'
    #     llms.documentation do |docs|
    #       docs.link 'API', 'api.md'
    #     end
    #   end.build
    def build(&)
      builder = Builders::DslBuilder.new
      builder.instance_eval(&) if block_given?
      builder
    end

    # Builds llms.txt content from a predefined template
    #
    # @param template [Builders::Template] the template to use
    # @param context [Hash] template context variables
    # @option context [String] :title project title
    # @option context [String] :description project description
    # @option context [String] :license license type
    # @option context [String] :homepage project homepage URL
    #
    # @return [Builders::DslBuilder] the configured builder
    #
    # @example Build from template
    #   template = LlmsTxt::Builders::Templates.ruby_gem
    #   content = LlmsTxt.build_from_template(template,
    #     title: 'My Gem',
    #     description: 'A Ruby library',
    #     license: 'MIT'
    #   ).build
    def build_from_template(template, context = {})
      template.build(context)
    end
  end
end
