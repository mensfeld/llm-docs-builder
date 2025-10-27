# frozen_string_literal: true

RSpec.describe 'generate command' do
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

  it 'excludes files based on config excludes patterns' do
    # Create documentation with files to be excluded
    File.write(File.join(temp_dir, 'README.md'), "# Project\n\nMain documentation")
    File.write(File.join(temp_dir, 'guide.md'), "# Guide\n\nUser guide")
    File.write(File.join(temp_dir, 'draft.md'), "# Draft\n\nDraft content")
    File.write(File.join(temp_dir, 'internal.md'), "# Internal\n\nInternal notes")

    # Create config with excludes
    config_file = File.join(temp_dir, 'config.yml')
    output_file = File.join(temp_dir, 'llms.txt')

    File.write(config_file, <<~YAML)
      docs: #{temp_dir}
      output: #{output_file}
      excludes:
        - draft.md
        - internal.md
    YAML

    # Run generate command
    _, _stderr, status = run_cli('generate', '--config', config_file)

    # Verify success
    expect(status.success?).to be true

    # Verify content excludes the specified files
    content = File.read(output_file)
    expect(content).to include('Project')
    expect(content).to include('Guide')
    expect(content).not_to include('Draft')
    expect(content).not_to include('Internal')
  end

  it 'excludes files in directories matching glob patterns' do
    # Create directory structure
    private_dir = File.join(temp_dir, 'private')
    FileUtils.mkdir_p(private_dir)

    File.write(File.join(temp_dir, 'README.md'), "# Project\n\nDocumentation")
    File.write(File.join(private_dir, 'secret.md'), "# Secret\n\nSecret content")
    File.write(File.join(private_dir, 'internal.md'), "# Internal\n\nInternal docs")

    # Create config excluding private directory
    config_file = File.join(temp_dir, 'config.yml')
    output_file = File.join(temp_dir, 'llms.txt')

    File.write(config_file, <<~YAML)
      docs: #{temp_dir}
      output: #{output_file}
      excludes:
        - "**/private/**"
    YAML

    # Run generate command
    _, _stderr, status = run_cli('generate', '--config', config_file)

    expect(status.success?).to be true

    content = File.read(output_file)
    expect(content).to include('Project')
    expect(content).not_to include('Secret')
    expect(content).not_to include('Internal')
  end

  it 'excludes files matching wildcard patterns' do
    File.write(File.join(temp_dir, 'README.md'), "# Project\n\nDocumentation")
    File.write(File.join(temp_dir, 'draft-proposal.md'), "# Draft Proposal\n\nDraft")
    File.write(File.join(temp_dir, 'draft-notes.md'), "# Draft Notes\n\nNotes")
    File.write(File.join(temp_dir, 'final.md'), "# Final\n\nFinal version")

    config_file = File.join(temp_dir, 'config.yml')
    output_file = File.join(temp_dir, 'llms.txt')

    File.write(config_file, <<~YAML)
      docs: #{temp_dir}
      output: #{output_file}
      excludes:
        - "draft-*.md"
    YAML

    _, _stderr, status = run_cli('generate', '--config', config_file)

    expect(status.success?).to be true

    content = File.read(output_file)
    expect(content).to include('Project')
    expect(content).to include('Final')
    expect(content).not_to include('Draft Proposal')
    expect(content).not_to include('Draft Notes')
  end

  it 'calculates token count from transformed content when transformations are enabled' do
    # Create single file with lots of comments that will be removed
    test_file = File.join(temp_dir, 'test.md')
    File.write(test_file, <<~MD)
      # Test Document

      <!-- This is a very long comment that adds many tokens but should be removed during transformation process -->
      <!-- Another long comment here that also adds to the token count unnecessarily and makes the file bigger -->
      <!-- Yet another comment to ensure significant difference in token count after transformation happens -->
      <!-- One more comment just to be absolutely sure we have enough tokens to see a meaningful difference here -->

      This is the actual content that matters for the documentation.

      <!-- More comments in the middle of the content to add even more tokens -->
      <!-- These should all be removed when transformations are enabled in the configuration -->

      Additional content paragraph here.
    MD

    # Generate without transformations
    config_no_transform = File.join(temp_dir, 'config_no_transform.yml')
    output_no_transform = File.join(temp_dir, 'llms_no_transform.txt')

    File.write(config_no_transform, <<~YAML)
      docs: #{test_file}
      output: #{output_no_transform}
      include_metadata: true
      include_tokens: true
      remove_comments: false
      normalize_whitespace: false
      remove_badges: false
      remove_frontmatter: false
    YAML

    run_cli('generate', '--config', config_no_transform)
    content_no_transform = File.read(output_no_transform)

    # Extract token count (format is "tokens:XX")
    tokens_no_transform = content_no_transform.match(/tokens:(\d+)/)[1].to_i

    # Generate with transformations
    config_with_transform = File.join(temp_dir, 'config_with_transform.yml')
    output_with_transform = File.join(temp_dir, 'llms_with_transform.txt')

    File.write(config_with_transform, <<~YAML)
      docs: #{test_file}
      output: #{output_with_transform}
      include_metadata: true
      include_tokens: true
      remove_comments: true
    YAML

    run_cli('generate', '--config', config_with_transform)
    content_with_transform = File.read(output_with_transform)

    tokens_with_transform = content_with_transform.match(/tokens:(\d+)/)[1].to_i

    # Token count should be significantly lower after removing comments
    expect(tokens_with_transform).to be < tokens_no_transform
    expect(tokens_no_transform - tokens_with_transform).to be >= 20
  end
end
