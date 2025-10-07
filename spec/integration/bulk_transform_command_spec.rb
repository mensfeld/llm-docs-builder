# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'tempfile'
require 'tmpdir'

RSpec.describe 'bulk-transform command', :integration do
  let(:cli_path) { File.expand_path('../../bin/llms-txt', __dir__) }
  let(:temp_dir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  def run_cli(*args)
    cmd = "bundle exec #{cli_path} #{args.join(' ')}"
    stdout, stderr, status = Open3.capture3(cmd)
    [stdout, stderr, status]
  end

  it 'transforms all markdown files in directory recursively' do
    # Create directory structure with multiple markdown files
    docs_dir = File.join(temp_dir, 'docs')
    FileUtils.mkdir_p(File.join(docs_dir, 'api'))

    File.write(File.join(docs_dir, 'README.md'), "# README\n\nContent here")
    File.write(File.join(docs_dir, 'guide.md'), "# Guide\n\nGuide content")
    File.write(File.join(docs_dir, 'api', 'reference.md'), "# API\n\nAPI docs")

    # Run bulk-transform
    stdout, _stderr, status = run_cli('bulk-transform', '--docs', docs_dir)

    # Verify success
    expect(status.success?).to be true
    expect(stdout).to include('Successfully transformed')
    expect(stdout).to include('3 files')

    # Verify transformed files exist with default .llm.md suffix
    expect(File.exist?(File.join(docs_dir, 'README.llm.md'))).to be true
    expect(File.exist?(File.join(docs_dir, 'guide.llm.md'))).to be true
    expect(File.exist?(File.join(docs_dir, 'api', 'reference.llm.md'))).to be true
  end

  it 'works with custom suffix from config file' do
    # Create docs
    docs_dir = File.join(temp_dir, 'docs')
    FileUtils.mkdir_p(docs_dir)
    File.write(File.join(docs_dir, 'README.md'), "# README\n\nContent")

    # Create config with custom suffix
    config_file = File.join(temp_dir, 'config.yml')
    File.write(config_file, <<~YAML)
      docs: #{docs_dir}
      suffix: .ai
      base_url: https://example.com
    YAML

    # Run bulk-transform with config
    _, _stderr, status = run_cli('bulk-transform', '--config', config_file)

    # Verify custom suffix was used
    expect(status.success?).to be true
    expect(File.exist?(File.join(docs_dir, 'README.ai.md'))).to be true
  end

  it 'fails when directory does not exist' do
    stdout, _stderr, status = run_cli(
      'bulk-transform',
      '--docs', '/nonexistent/directory'
    )

    expect(status.success?).to be false
    expect(status.exitstatus).to eq(1)
    expect(stdout).to include('Documentation path not found')
  end
end
