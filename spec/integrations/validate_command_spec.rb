# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'tempfile'
require 'tmpdir'

RSpec.describe 'validate command' do
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

  it 'validates valid llms.txt file' do
    # Create valid llms.txt file
    valid_file = File.join(temp_dir, 'valid.txt')
    File.write(valid_file, <<~CONTENT)
      # Valid Project

      > A valid llms.txt file

      ## Documentation

      - [Docs](docs/): Documentation
    CONTENT

    # Run validate command
    stdout, _stderr, status = run_cli('validate', '--docs', valid_file)

    # Verify success
    expect(status.success?).to be true
    expect(stdout).to include('Valid llms.txt file')
  end

  it 'rejects invalid llms.txt file' do
    # Create invalid llms.txt file
    invalid_file = File.join(temp_dir, 'invalid.txt')
    File.write(invalid_file, 'Invalid content without proper structure')

    # Run validate command
    stdout, _stderr, status = run_cli('validate', '--docs', invalid_file)

    # Verify failure
    expect(status.success?).to be false
    expect(status.exitstatus).to eq(1)
    expect(stdout).to include('Invalid llms.txt file')
    expect(stdout).to include('Errors:')
  end
end
