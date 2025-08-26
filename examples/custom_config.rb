#!/usr/bin/env ruby
# frozen_string_literal: true

# Example of custom configuration for llms-txt-ruby
# Shows advanced configuration options

require 'llms_txt'

# Advanced configuration
LlmsTxt.configure do |config|
  # Provider settings
  config.llm_provider = :openai
  config.api_key = ENV.fetch('OPENAI_API_KEY', nil)
  config.model = 'gpt-4-turbo-preview'
  config.temperature = 0.2

  # Output settings
  config.output_path = 'custom_llms.txt'
  config.include_optional = false # Skip optional section
  config.verbose = true

  # File analysis settings
  config.file_analyzers = %i[readme gemspec yard examples]

  # Exclude certain files
  config.exclude_patterns = %w[
    vendor/**/*
    tmp/**/*
    log/**/*
    coverage/**/*
    .git/**/*
    *.gem
    node_modules/**/*
  ]

  # Auto-detect documentation
  config.auto_detect_docs = true
end

# Custom analysis with specific project directory
project_options = {
  project_root: '/path/to/my/ruby/project',
  output: 'project_specific_llms.txt',
  include_optional: true,
  no_llm: false
}

# Generate with custom options
begin
  content = LlmsTxt.generate(project_options)
  puts "Generated custom llms.txt: #{content.lines.first}"
rescue LlmsTxt::Error => e
  puts "Error: #{e.message}"
end

# Example of parsing and validation workflow
if File.exist?('llms.txt')
  # Parse
  parsed_data = LlmsTxt.parse('llms.txt')

  puts "Project: #{parsed_data.title}"
  puts "Has documentation: #{parsed_data.documentation_links.any?}"
  puts "Has examples: #{parsed_data.example_links.any?}"

  # Convert to XML for LLM integration
  xml_content = parsed_data.to_xml
  File.write('llms_context.xml', xml_content)

  # Validate
  validator = LlmsTxt::Validator.new(File.read('llms.txt'))
  if validator.valid?
    puts '✓ llms.txt is valid'
  else
    puts '⚠ Validation issues found:'
    validator.errors.each { |error| puts "  - #{error}" }
  end
end
