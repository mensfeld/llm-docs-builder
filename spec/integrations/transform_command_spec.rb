# frozen_string_literal: true

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

  it 'matches the README compression example with default options' do
    input_file = File.join(temp_dir, 'test.md')
    output_file = File.join(temp_dir, 'output.md')

    File.write(input_file, <<~MD)
      ---
      layout: docs
      ---

      # API Documentation

      [![Build](badge.svg)](https://ci.com)

      > Important: This is a note

      [Click here to see the complete API documentation](./api.md)

      api = API.new
    MD

    _stdout, _stderr, status = run_cli(
      'transform',
      '--docs', input_file,
      '--output', output_file
    )

    expect(status.success?).to be true
    expect(File.read(output_file)).to eq(<<~MD.chomp)
      # API Documentation


      > Important: This is a note

      [Click here to see the complete API documentation](./api.md)

      api = API.new
    MD
  end

  it 'matches the README simplify_links example' do
    input_file = File.join(temp_dir, 'test.md')
    config_file = File.join(temp_dir, 'config.yml')
    output_file = File.join(temp_dir, 'output.md')

    File.write(input_file, <<~MD)
      [Click here to see the docs](./docs.md)

      [Click here to see the complete API guide](./api.md)
    MD

    File.write(config_file, <<~YAML)
      simplify_links: true
    YAML

    _stdout, _stderr, status = run_cli(
      'transform',
      '--docs', input_file,
      '--output', output_file,
      '--config', config_file
    )

    expect(status.success?).to be true
    expect(File.read(output_file)).to eq(<<~MD.chomp)
      [docs](./docs.md)

      [complete API guide](./api.md)
    MD
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

  it 'does not mix in llm-docs-builder.yml when --config names another file' do
    File.write(File.join(temp_dir, 'api.md'), "# API\n\nSee [setup](setup.md).\n")

    File.write(File.join(temp_dir, 'llm-docs-builder.yml'), <<~YAML)
      base_url: https://main.example
      custom_instruction: MAIN-ONLY INSTRUCTION
    YAML
    File.write(File.join(temp_dir, 'other.yml'), <<~YAML)
      remove_badges: true
    YAML

    stdout, _stderr, status = Open3.capture3(
      { 'BUNDLE_GEMFILE' => File.expand_path('../../Gemfile', __dir__) },
      "bundle exec #{cli_path} transform --config other.yml --docs api.md",
      chdir: temp_dir
    )

    expect(status.success?).to be true
    expect(stdout).not_to include('MAIN-ONLY INSTRUCTION')
    expect(stdout).not_to include('main.example')
    expect(stdout).to include('See [setup](setup.md).')
  end
end
