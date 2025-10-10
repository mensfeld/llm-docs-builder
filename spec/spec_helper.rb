# frozen_string_literal: true

require 'bundler/setup'
require 'llm_docs_builder'
require 'simplecov'
require 'tempfile'
require 'tmpdir'
require 'open3'
require 'fileutils'

SimpleCov.start do
  add_filter '/spec/'
end

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

  # Temporarily rename config file during tests to prevent auto-loading
  config.before(:suite) do
    config_file = 'llm-docs-builder.yml'
    if File.exist?(config_file)
      FileUtils.mv(config_file, "#{config_file}.backup")
    end
  end

  config.after(:suite) do
    backup_file = 'llm-docs-builder.yml.backup'
    if File.exist?(backup_file)
      FileUtils.mv(backup_file, 'llm-docs-builder.yml')
    end
  end
end
