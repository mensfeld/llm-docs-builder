# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'tempfile'
require 'tmpdir'

RSpec.describe 'generate command' do
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

  it 'generates llms.txt from documentation directory' do
    # Create sample documentation
    File.write(File.join(temp_dir, 'README.md'), <<~MD)
      # Test Project

      This is a test project for CLI integration testing.

      ## Features
      - Easy to use
      - Well tested
    MD

    File.write(File.join(temp_dir, 'api.md'), <<~MD)
      # API Reference

      Complete API documentation.
    MD

    # Create config file
    config_file = File.join(temp_dir, 'config.yml')
    output_file = File.join(temp_dir, 'llms.txt')

    File.write(config_file, <<~YAML)
      docs: #{temp_dir}
      output: #{output_file}
      title: Test Project
      description: This is a test project for CLI integration testing.
    YAML

    # Run generate command
    stdout, _stderr, status = run_cli('generate', '--config', config_file)

    # Verify success
    expect(status.success?).to be true
    expect(stdout).to include("Successfully generated #{output_file}")
    expect(File.exist?(output_file)).to be true

    # Verify content
    content = File.read(output_file)
    expect(content).to include('# Test Project')
    expect(content).to include('## Documentation')
    expect(content).to include('README')
    expect(content).to include('API Reference')
  end

  it 'generates with base URL for absolute links' do
    # Create documentation
    File.write(File.join(temp_dir, 'README.md'), "# Project\n\nDocumentation here")
    File.write(File.join(temp_dir, 'guide.md'), "# Guide\n\nGuide content")

    # Create config with base URL
    config_file = File.join(temp_dir, 'config.yml')
    output_file = File.join(temp_dir, 'llms.txt')

    File.write(config_file, <<~YAML)
      docs: #{temp_dir}
      base_url: https://example.com
      output: #{output_file}
    YAML

    # Run generate command
    _, _stderr, status = run_cli('generate', '--config', config_file)

    # Verify URLs are absolute
    expect(status.success?).to be true
    content = File.read(output_file)
    expect(content).to include('https://example.com/README.md')
    expect(content).to include('https://example.com/guide.md')
  end

  it 'fails when docs path does not exist' do
    config_file = File.join(temp_dir, 'config.yml')
    File.write(config_file, <<~YAML)
      docs: /nonexistent/path
      output: #{File.join(temp_dir, 'llms.txt')}
    YAML

    stdout, _stderr, status = run_cli('generate', '--config', config_file)

    expect(status.success?).to be false
    expect(status.exitstatus).to eq(1)
    expect(stdout).to include('Documentation path not found')
  end
end
