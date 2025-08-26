#!/usr/bin/env ruby
# frozen_string_literal: true

# Wiki processing example for llms-txt-ruby
# Shows how to use the gem with wiki directories and link processing

require 'llms_txt'

# Configure with wiki analysis enabled
LlmsTxt.configure do |config|
  config.llm_provider = :local # No API key needed
  config.file_analyzers = %i[readme gemspec wiki docs examples]
  config.verbose = true
end

puts 'Analyzing project with wiki support...'

# Analyze the wiki structure
wiki_analyzer = LlmsTxt::Analyzers::Wiki.new('.')
wiki_data = wiki_analyzer.analyze

if wiki_data[:total_files].positive?
  puts "\nWiki Analysis:"
  puts "  Found #{wiki_data[:total_files]} wiki files"
  puts "  Total words: #{wiki_data[:total_words]}"
  puts "  Navigation files: #{wiki_data[:navigation]&.keys&.size || 0}"

  if wiki_data[:link_analysis]
    puts "  Internal links: #{wiki_data[:link_analysis][:total_internal_links]}"
    puts "  Broken links: #{wiki_data[:link_analysis][:broken_links]&.size || 0}"
  end
else
  puts 'No wiki files found'
end

# Generate llms.txt with wiki content
puts "\nGenerating llms.txt with wiki integration..."
LlmsTxt.generate

# Demonstrate link expansion
puts "\nDemonstrating link expansion..."
if File.exist?('wiki/getting-started.md')
  expander = LlmsTxt::Utils::MarkdownLinkExpander.new(
    'wiki/getting-started.md',
    'https://llms-txt-ruby.io'
  )

  expanded = expander.expand_links
  puts 'Original content (first 200 chars):'
  puts File.read('wiki/getting-started.md')[0...200]
  puts "\nWith expanded links (first 200 chars):"
  puts expanded[0...200]
end

puts "\nGeneration complete! Check llms.txt for results."
