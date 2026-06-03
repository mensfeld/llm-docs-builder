# frozen_string_literal: true

Warning[:performance] = true if RUBY_VERSION >= '3.3'
Warning[:deprecated] = true
$VERBOSE = true

if Warning.respond_to?(:categories)
  (Warning.categories - %i[experimental]).each do |cat|
    Warning[cat] = true
  end
end

require 'warning'

Warning.process do |warning|
  next unless warning.include?(Dir.pwd)
  next if warning.include?('_spec')
  next if warning.include?('previous definition of')
  next if warning.include?('method redefined')
  next if warning.include?('vendor/')
  next if warning.include?('bundle/')
  next if warning.include?('.bundle/')
  raise "Warning in your code: #{warning}"
end

require 'bundler/setup'
require 'llm_docs_builder'
require 'simplecov'
require 'tempfile'
require 'tmpdir'
require 'open3'
require 'fileutils'

SimpleCov.start do
  add_filter '/spec/'
  enable_coverage :branch
  primary_coverage :line
end unless ENV['SIMPLECOV'] == 'false'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed
end
