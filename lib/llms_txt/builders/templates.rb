# frozen_string_literal: true

module LlmsTxt
  module Builders
    # Collection of predefined templates for common project types
    #
    # Provides ready-to-use templates that can be customized for different
    # types of Ruby projects. Each template includes sensible defaults for
    # sections, auto-discovery patterns, and common links.
    #
    # @example Using a template
    #   template = LlmsTxt::Builders::Templates.ruby_gem
    #   content = LlmsTxt.build_from_template(template,
    #     title: 'My Gem',
    #     description: 'A Ruby library',
    #     license: 'MIT'
    #   ).build
    class Templates
      # Template optimized for Ruby gems
      #
      # Includes documentation auto-discovery, examples section with file discovery,
      # and optional section with standard gem links (changelog, license, homepage).
      #
      # @return [Template] configured template for Ruby gems
      #
      # @example
      #   template = LlmsTxt::Builders::Templates.ruby_gem
      #   content = LlmsTxt.build_from_template(template,
      #     title: 'my-awesome-gem',
      #     description: 'A Ruby library for awesome things',
      #     license: 'MIT',
      #     homepage: 'https://github.com/user/my-awesome-gem'
      #   ).build
      def self.ruby_gem
        Template.new do
          header :title, :description

          documentation(required: true) do |docs|
            docs.auto_discover_docs
            docs.link('API Documentation', 'https://rubydoc.info/gems/{gem_name}') if respond_to?(:gem_name)
          end

          examples auto_discover: 'examples/**/*.rb'

          optional standard_ruby_gem_links: true
        end
      end

      # Template optimized for Rails applications
      #
      # Includes documentation discovery from Rails-style doc directories,
      # API endpoints section for controller discovery, and examples.
      #
      # @return [Template] configured template for Rails apps
      #
      # @example
      #   template = LlmsTxt::Builders::Templates.rails_app
      #   content = LlmsTxt.build_from_template(template,
      #     title: 'My Rails App',
      #     description: 'A Ruby on Rails application',
      #     homepage: 'https://myapp.com'
      #   ).build
      def self.rails_app
        Template.new do
          header :title, :description

          documentation(required: true) do |docs|
            docs.auto_discover('doc/**/*.md')
            docs.link('API Documentation', '/api-docs')
          end

          section 'API Endpoints' do |api|
            api.auto_discover('app/controllers/**/*_controller.rb', type: :controllers)
          end

          examples auto_discover: 'examples/**/*.rb'
          optional standard_ruby_gem_links: true
        end
      end

      # Simple template with basic sections
      #
      # Provides a minimal template with required documentation, examples,
      # and optional sections. Sections appear even if empty.
      #
      # @return [Template] basic template with essential sections
      #
      # @example
      #   template = LlmsTxt::Builders::Templates.simple
      #   content = LlmsTxt.build_from_template(template,
      #     title: 'Simple Project',
      #     description: 'A straightforward project'
      #   ).build
      def self.simple
        Template.new do
          header :title, :description
          documentation(required: true)
          examples(required: true)
          optional(required: true)
        end
      end

      # Comprehensive template with extensive auto-discovery
      #
      # Includes multiple sections with auto-discovery for documentation,
      # examples, guides, and API reference. Suitable for large projects
      # with extensive documentation.
      #
      # @return [Template] comprehensive template with multiple sections
      #
      # @example
      #   template = LlmsTxt::Builders::Templates.comprehensive
      #   content = LlmsTxt.build_from_template(template,
      #     title: 'Large Project',
      #     description: 'A comprehensive Ruby project',
      #     license: 'Apache-2.0'
      #   ).build
      def self.comprehensive
        Template.new do
          header :title, :description

          documentation(required: true, &:auto_discover_docs)

          examples(&:auto_discover_examples)

          section 'Guides' do |guides|
            guides.auto_discover('guides/**/*.md', type: :documentation)
          end

          section 'API Reference' do |api|
            api.auto_discover('lib/**/*.rb', type: :code)
          end

          optional standard_ruby_gem_links: true
        end
      end
    end
  end
end
