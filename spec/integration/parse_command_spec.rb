# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'tempfile'
require 'tmpdir'

RSpec.describe 'parse command', :integration do
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

  it 'parses llms.txt file and displays information' do
    # Create llms.txt file
    llms_file = File.join(temp_dir, 'llms.txt')
    File.write(llms_file, <<~CONTENT)
      # Test Project

      > A sample project for testing

      ## Documentation

      - [README](docs/README.md): Project overview
      - [API Reference](docs/api.md): API documentation
    CONTENT

    # Run parse command with verbose flag
    stdout, _stderr, status = run_cli('parse', '--docs', llms_file, '--verbose')

    # Verify parsing output
    expect(status.success?).to be true
    expect(stdout).to include('Title: Test Project')
    expect(stdout).to include('Description: A sample project for testing')
    expect(stdout).to include('Documentation Links:')
  end

  it 'fails when file does not exist' do
    stdout, _stderr, status = run_cli('parse', '--docs', '/nonexistent/llms.txt')

    expect(status.success?).to be false
    expect(status.exitstatus).to eq(1)
    expect(stdout).to include('File not found')
  end
end
