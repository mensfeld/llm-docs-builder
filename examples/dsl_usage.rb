#!/usr/bin/env ruby
# frozen_string_literal: true

# DSL usage examples for llms-txt-ruby
# Shows the new composable DSL for building llms.txt files

require 'llms_txt'

puts '=== LlmsTxt DSL Examples ==='

# Example 1: Basic DSL usage
puts "\n1. Basic DSL Usage:"
puts '==================='

content = LlmsTxt.build do |llms|
  llms.title 'My Awesome Gem'
  llms.description 'A Ruby library for processing data with advanced algorithms'

  llms.documentation do |docs|
    docs.link 'API Reference', 'https://rubydoc.info/gems/my_gem',
              description: 'Complete API documentation'
    docs.link 'Getting Started', 'docs/getting_started.md',
              description: 'Quick start guide'
  end

  llms.examples do |examples|
    examples.auto_discover_examples('examples/**/*.rb')
    examples.link 'Advanced Patterns', 'examples/advanced.rb'
  end

  llms.optional do |opt|
    opt.changelog
    opt.license('MIT')
    opt.homepage('https://github.com/user/my_gem')
  end
end

puts content.build
puts "\n#{'=' * 50}"

# Example 2: Using Predefined Templates
puts "\n2. Using Templates:"
puts '=================='

template = LlmsTxt::Builders::Templates.ruby_gem
content = LlmsTxt.build_from_template(template,
                                      title: 'llms-txt-ruby',
                                      description: 'Ruby implementation of the llms.txt specification',
                                      license: 'MIT',
                                      homepage: 'https://github.com/mensfeld/llms-txt-ruby')

puts content.build
puts "\n#{'=' * 50}"

# Example 3: Custom Template
puts "\n3. Custom Template:"
puts '=================='

my_template = LlmsTxt::Builders::Template.new do
  header :title, :description

  documentation(required: true) do |docs|
    docs.auto_discover_docs('docs/**/*.md')
  end

  section('API Endpoints') do |api|
    api.link('Health Check', '/health', description: 'Application health endpoint')
    api.link('User API', '/api/users', description: 'User management API')
  end

  examples(auto_discover: 'examples/**/*.rb')
  optional(standard_ruby_gem_links: true)
end

content = LlmsTxt.build_from_template(my_template,
                                      title: 'My Web API',
                                      description: 'RESTful API for user management')

puts content.build
puts "\n#{'=' * 50}"

# Example 4: Template Customization
puts "\n4. Template Customization:"
puts '========================='

customized = LlmsTxt::Builders::Templates.simple.customize(
  title: 'Customized Project',
  description: 'A project with custom sections'
) do |builder|
  builder.section('Deployment') do |deploy|
    deploy.link('Docker', 'Dockerfile', description: 'Container configuration')
    deploy.link('Kubernetes', 'k8s/', description: 'Kubernetes manifests')
  end

  builder.section('Monitoring') do |monitor|
    monitor.link('Metrics', '/metrics', description: 'Prometheus metrics')
    monitor.link('Health', '/health', description: 'Health check endpoint')
  end
end

puts customized.build
puts "\n#{'=' * 50}"

# Example 5: Fluent Interface
puts "\n5. Fluent Interface:"
puts '==================='

content = LlmsTxt::Builders::DslBuilder.new
                                       .title('Fluent Example')
                                       .description('Demonstrating the fluent interface')
                                       .section('Quick Links') { |q| q.link('Home', '/') }
                                       .documentation { |d| d.link('Guide', 'guide.md') }
                                       .examples { |e| e.link('Basic', 'basic.rb') }

puts content.build

puts "\nDSL demonstration complete!"
