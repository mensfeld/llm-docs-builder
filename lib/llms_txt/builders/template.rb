# frozen_string_literal: true

module LlmsTxt
  module Builders
    class Template
      attr_reader :sections_config, :header_config, :defaults

      def initialize(&)
        @sections_config = []
        @header_config = {}
        @defaults = {}
        instance_eval(&) if block_given?
      end

      # Header configuration
      def header(*fields, **options)
        fields.each do |field|
          @header_config[field] = options
        end
        self
      end

      # Section configuration
      def section(name, **options, &block)
        section_config = {
          name: name,
          options: options,
          block: block
        }
        @sections_config << section_config
        self
      end

      # Predefined section shortcuts
      def documentation(...)
        section('Documentation', ...)
      end

      def examples(...)
        section('Examples', ...)
      end

      def optional(...)
        section('Optional', ...)
      end

      # Default values
      def defaults(**values)
        @defaults.merge!(values)
        self
      end

      # Apply template to a DSL builder
      def apply_to(builder, context = {})
        # Apply header configuration
        apply_header(builder, context)

        # Apply sections
        @sections_config.each do |section_config|
          apply_section(builder, section_config, context)
        end

        builder
      end

      # Create a new DSL builder from this template
      def build(context = {})
        builder = DslBuilder.new
        apply_to(builder, context)
        builder
      end

      # Allow customization of the template
      def customize(context = {}, &)
        builder = build(context)
        builder.instance_eval(&) if block_given?
        builder
      end

      private

      def apply_header(builder, context)
        merged_context = @defaults.merge(context)

        builder.title(merged_context[:title]) if @header_config[:title] && merged_context[:title]

        return unless @header_config[:description] && merged_context[:description]

        builder.description(merged_context[:description])
      end

      def apply_section(builder, section_config, context)
        name = section_config[:name]
        options = section_config[:options]
        block = section_config[:block]

        # Skip section only if it's explicitly marked as not required AND not provided in context
        # If required is true or not set, always include the section
        return if options.key?(:required) && options[:required] == false && !context[name.downcase.to_sym]

        # Store reference to template for use in block
        template_ref = self

        # Template sections are required by default unless explicitly marked otherwise
        section_options = options.dup
        section_options[:required] = true unless section_options.key?(:required)

        builder.section(name, section_options) do |section|
          # Apply auto-discovery if configured
          if options[:auto_discover]
            pattern = options[:auto_discover]
            section.auto_discover(pattern, type: name.downcase.to_sym)
          end

          # Apply any predefined block
          section.instance_eval(&block) if block

          # Apply standard shortcuts if configured
          template_ref.send(:apply_standard_shortcuts_to_section, section, options, context)
        end
      end

      def apply_standard_shortcuts_to_section(section, options, context)
        case section.name.downcase
        when 'optional'
          apply_standard_ruby_gem_links(section, context) if options[:standard_ruby_gem_links]
        end
      end

      def apply_standard_ruby_gem_links(section, context)
        # Standard Ruby gem links
        section.changelog if File.exist?('CHANGELOG.md')
        section.contributing if File.exist?('CONTRIBUTING.md')
        section.license(context[:license] || 'MIT') if File.exist?('LICENSE')
        section.homepage(context[:homepage]) if context[:homepage]

        # Gemspec-based links
        return unless context[:gemspec_data]

        gemspec = context[:gemspec_data]
        section.homepage(gemspec[:homepage]) if gemspec[:homepage]
        section.link('Source Code', gemspec[:source_code_uri]) if gemspec[:source_code_uri]
        section.link('Bug Reports', gemspec[:bug_tracker_uri]) if gemspec[:bug_tracker_uri]
        section.link('Documentation', gemspec[:documentation_uri]) if gemspec[:documentation_uri]
      end
    end
  end
end
