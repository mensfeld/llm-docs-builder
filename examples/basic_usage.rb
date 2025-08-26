#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic usage example for llms-txt-ruby
# This example shows how to generate an llms.txt file using the Ruby API

require 'llms_txt'

# Configure the gem
LlmsTxt.configure do |config|
  config.llm_provider = :local # Use local template generation
  config.output_path = 'my_project_llms.txt'
  config.verbose = true
end

# Generate llms.txt file for the current project
puts 'Generating llms.txt file...'
content = LlmsTxt.generate

puts "\nGenerated content:\n#{content}"

# Parse an existing llms.txt file
if File.exist?('llms.txt')
  puts "\nParsing existing llms.txt file..."
  parsed = LlmsTxt.parse('llms.txt')

  puts "Title: #{parsed.title}"
  puts "Description: #{parsed.description}"
  puts "Documentation links: #{parsed.documentation_links.size}"

  # Convert to XML format for LLM consumption
  puts "\nXML format:"
  puts parsed.to_xml
end

# Validate content
puts "\nValidating content..."
validator = LlmsTxt.validate(content)
puts validator ? '✓ Valid' : '✗ Invalid'
