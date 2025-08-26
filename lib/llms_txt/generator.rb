# frozen_string_literal: true

module LlmsTxt
  class Generator
    attr_reader :options, :project_root

    def initialize(options = {})
      @options = options
      @project_root = options[:project_root] || Dir.pwd
      @config = LlmsTxt.configuration
    end

    def generate
      validate_project!

      project_data = analyze_project
      prompt = build_prompt(project_data)

      if options[:no_llm]
        generate_template(project_data)
      else
        generate_with_llm(prompt, project_data)
      end
    end

    private

    def validate_project!
      gemspec_path = Dir.glob(File.join(project_root, '*.gemspec')).first
      raise GenerationError, 'No gemspec file found in project root' unless gemspec_path

      return if File.exist?(File.join(project_root, 'lib'))

      raise GenerationError, 'No lib directory found in project root'
    end

    def analyze_project
      data = {}

      @config.file_analyzers.each do |analyzer_name|
        analyzer = load_analyzer(analyzer_name)
        next unless analyzer

        puts "Analyzing #{analyzer_name}..." if @config.verbose
        data[analyzer_name] = analyzer.analyze
      end

      data
    end

    def load_analyzer(name)
      case name
      when :readme
        Analyzers::Readme.new(project_root)
      when :gemspec
        Analyzers::Gemspec.new(project_root)
      when :yard
        Analyzers::Yard.new(project_root)
      when :changelog
        Analyzers::Changelog.new(project_root)
      when :examples
        Analyzers::Examples.new(project_root)
      when :docs
        Analyzers::Docs.new(project_root)
      when :wiki
        Analyzers::Wiki.new(project_root)
      end
    end

    def build_prompt(project_data)
      Builders::PromptBuilder.new(project_data, options).build
    end

    def generate_template(project_data)
      content = Builders::ContentBuilder.new(project_data, options).build_template
      output_path = options[:output] || @config.output_path
      File.write(output_path, content)
      puts "Template saved to #{output_path}" if @config.verbose
      content
    end

    def generate_with_llm(prompt, project_data)
      response = @config.llm_client.complete(prompt)

      content = if response.is_a?(String) && !response.empty?
                  response
                else
                  # Fallback to template generation if LLM returns nil or empty
                  Builders::ContentBuilder.new(project_data, options).build_template
                end

      validate_and_save(content)
    end

    def validate_and_save(content)
      # Post-process content if needed
      content = post_process_content(content)

      validator = Validator.new(content)

      unless validator.valid?
        puts 'Warning: Generated content has validation issues:' if @config.verbose
        validator.errors.each { |error| puts "  - #{error}" } if @config.verbose
      end

      output_path = options[:output] || @config.output_path
      File.write(output_path, content)

      puts "Successfully generated #{output_path}" if @config.verbose
      content
    end

    def post_process_content(content)
      # Apply link expansion if requested
      if options[:expand_links]
        require 'tempfile'
        temp_file = Tempfile.new(['llms_txt', '.md'])
        temp_file.write(content)
        temp_file.close

        expander = Utils::MarkdownLinkExpander.new(temp_file.path, options[:expand_links])
        content = expander.to_s

        temp_file.unlink
      end

      # Apply URL conversion if requested
      if options[:convert_urls]
        require 'tempfile'
        temp_file = Tempfile.new(['llms_txt', '.md'])
        temp_file.write(content)
        temp_file.close

        converter = Utils::MarkdownUrlConverter.new(temp_file.path)
        content = converter.to_s

        temp_file.unlink
      end

      content
    end
  end
end
