# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'tempfile'
require 'tmpdir'

RSpec.describe 'transform command' do
  let(:cli_path) { File.expand_path('../../bin/llm-docs-builder', __dir__) }
  let(:temp_dir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  def run_cli(*args)
    cmd = "bundle exec #{cli_path} #{args.join(' ')}"
    stdout, stderr, status = Open3.capture3(cmd)
    [stdout, stderr, status]
  end

  it 'transforms markdown file with base URL expansion' do
    # Create markdown file with relative links
    input_file = File.join(temp_dir, 'test.md')
    File.write(input_file, <<~MD)
      # Test Document

      Check out the [API docs](./api.md) and [guide](docs/guide.md).

      Also see https://example.com/page.html
    MD

    # Create config with base URL
    config_file = File.join(temp_dir, 'config.yml')
    output_file = File.join(temp_dir, 'output.md')

    File.write(config_file, <<~YAML)
      base_url: https://mysite.com
    YAML

    # Run transform command
    stdout, _stderr, status = run_cli(
      'transform',
      '--docs', input_file,
      '--output', output_file,
      '--config', config_file
    )

    # Verify success
    expect(status.success?).to be true
    expect(stdout).to include("Transformed content saved to #{output_file}")
    expect(File.exist?(output_file)).to be true

    # Verify transformed content
    content = File.read(output_file)
    expect(content).to include('[API docs](https://mysite.com/api.md)')
    expect(content).to include('[guide](https://mysite.com/docs/guide.md)')
  end

  it 'fails when file does not exist' do
    output_file = File.join(temp_dir, 'output.md')

    stdout, _stderr, status = run_cli(
      'transform',
      '--docs', '/nonexistent/file.md',
      '--output', output_file
    )

    expect(status.success?).to be false
    expect(status.exitstatus).to eq(1)
    expect(stdout).to include('File not found')
  end
end
