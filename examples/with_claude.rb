#!/usr/bin/env ruby
# frozen_string_literal: true

# Example of using llms-txt-ruby with Claude AI
# This example requires an Anthropic API key

require 'llms_txt'

# Configure to use Claude
LlmsTxt.configure do |config|
  config.llm_provider = :claude
  config.api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
  config.model = 'claude-3-opus-20240229'
  config.temperature = 0.3
  config.max_tokens = 4096
  config.verbose = true

  # Customize analysis
  config.file_analyzers = %i[readme gemspec yard changelog examples docs]
  config.include_optional = true
end

# Generate AI-powered llms.txt
begin
  puts 'Generating llms.txt with Claude AI...'

  content = LlmsTxt.generate(
    project_root: Dir.pwd,
    output: 'ai_generated_llms.txt'
  )

  puts 'Successfully generated AI-powered llms.txt!'
  puts "\nFirst 500 characters:"
  puts content[0...500]
rescue LlmsTxt::ConfigurationError => e
  puts "Configuration error: #{e.message}"
  puts 'Please set your ANTHROPIC_API_KEY environment variable'
rescue LlmsTxt::GenerationError => e
  puts "Generation error: #{e.message}"
rescue StandardError => e
  puts "Unexpected error: #{e.message}"
end
