# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'tmpdir'

RSpec.describe LlmDocsBuilder::BulkTransformer do
  let(:temp_dir) { Dir.mktmpdir }

  before do
    # Create nested directory structure with markdown files
    FileUtils.mkdir_p(File.join(temp_dir, 'docs', 'api'))
    FileUtils.mkdir_p(File.join(temp_dir, 'guides'))

    # Main README
    File.write(File.join(temp_dir, 'README.md'), <<~MD)
      # Test Project

      Welcome to our test project. See [API docs](./docs/api/endpoints.md).

      Visit https://example.com/docs.html for more info.
    MD

    # API documentation
    File.write(File.join(temp_dir, 'docs', 'api', 'endpoints.md'), <<~MD)
      # API Endpoints

      Check the [getting started guide](../../guides/getting-started.md).
    MD

    # Guide
    File.write(File.join(temp_dir, 'guides', 'getting-started.md'), <<~MD)
      # Getting Started

      This guide helps you get started.
    MD

    # File to exclude
    File.write(File.join(temp_dir, 'docs', 'private.md'), <<~MD)
      # Private Documentation

      This should be excluded.
    MD

    # Non-markdown file (should be ignored)
    File.write(File.join(temp_dir, 'README.txt'), 'This is not markdown')
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe '#initialize' do
    it 'sets default options' do
      transformer = described_class.new(temp_dir)

      expect(transformer.docs_path).to eq(temp_dir)
      expect(transformer.options[:suffix]).to eq('.llm')
      expect(transformer.options[:excludes]).to eq([])
    end

    it 'accepts custom options' do
      transformer = described_class.new(
        temp_dir,
        suffix: '.ai',
        excludes: ['**/private.md'],
        base_url: 'https://example.com'
      )

      expect(transformer.options[:suffix]).to eq('.ai')
      expect(transformer.options[:excludes]).to eq(['**/private.md'])
      expect(transformer.options[:base_url]).to eq('https://example.com')
    end
  end

  describe '#transform_all' do
    it 'transforms all markdown files in directory' do
      transformer = described_class.new(
        temp_dir,
        base_url: 'https://myproject.io'
      )

      transformed_files = transformer.transform_all

      expect(transformed_files.size).to eq(4) # All 4 .md files
      expect(transformed_files).to all(match(/\.llm\.md$/))

      # Check files were created
      expect(File.exist?(File.join(temp_dir, 'README.llm.md'))).to be true
      expect(File.exist?(File.join(temp_dir, 'docs', 'api', 'endpoints.llm.md'))).to be true
      expect(File.exist?(File.join(temp_dir, 'guides', 'getting-started.llm.md'))).to be true
      expect(File.exist?(File.join(temp_dir, 'docs', 'private.llm.md'))).to be true
    end

    it 'applies transformations to content' do
      transformer = described_class.new(
        temp_dir,
        base_url: 'https://myproject.io',
        convert_urls: true
      )

      transformer.transform_all

      # Check README transformation
      readme_content = File.read(File.join(temp_dir, 'README.llm.md'))
      expect(readme_content).to include('[API docs](https://myproject.io/docs/api/endpoints.md)')
      expect(readme_content).to include('https://example.com/docs.md') # .html converted to .md
    end

    it 'respects exclusion patterns' do
      transformer = described_class.new(
        temp_dir,
        excludes: ['**/private.md', '**/guides/**']
      )

      transformed_files = transformer.transform_all

      expect(transformed_files.size).to eq(2) # Only README and endpoints
      expect(File.exist?(File.join(temp_dir, 'docs', 'private.llm.md'))).to be false
      expect(File.exist?(File.join(temp_dir, 'guides', 'getting-started.llm.md'))).to be false
    end

    it 'uses custom suffix' do
      transformer = described_class.new(temp_dir, suffix: '.ai')

      transformed_files = transformer.transform_all

      expect(transformed_files).to all(match(/\.ai\.md$/))
      expect(File.exist?(File.join(temp_dir, 'README.ai.md'))).to be true
    end

    it 'raises error for non-existent directory' do
      transformer = described_class.new('/non/existent/path')

      expect do
        transformer.transform_all
      end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /Directory not found/)
    end

    it 'handles empty directory' do
      empty_dir = Dir.mktmpdir
      transformer = described_class.new(empty_dir)

      begin
        transformed_files = transformer.transform_all
        expect(transformed_files).to be_empty
      ensure
        FileUtils.rm_rf(empty_dir)
      end
    end
  end
end

RSpec.describe 'LlmDocsBuilder.bulk_transform' do
  let(:temp_dir) { Dir.mktmpdir }
  let(:config_file) { File.join(temp_dir, 'llm-docs-builder.yml') }

  before do
    # Create test files
    File.write(File.join(temp_dir, 'README.md'), <<~MD)
      # Test Project

      See [docs](./docs.md) for details.
    MD

    File.write(File.join(temp_dir, 'docs.md'), <<~MD)
      # Documentation

      This is the documentation.
    MD

    # Create config file
    File.write(config_file, <<~YAML)
      base_url: https://config-test.com
      suffix: .llm
      convert_urls: true
      excludes:
        - "**/private.md"
      verbose: false
    YAML
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  it 'works with direct options' do
    transformed_files = LlmDocsBuilder.bulk_transform(
      temp_dir,
      base_url: 'https://direct.com',
      suffix: '.direct'
    )

    expect(transformed_files.size).to eq(2)
    expect(transformed_files).to all(match(/\.direct\.md$/))

    content = File.read(File.join(temp_dir, 'README.direct.md'))
    expect(content).to include('[docs](https://direct.com/docs.md)')
  end

  it 'works with config file' do
    transformed_files = LlmDocsBuilder.bulk_transform(temp_dir, config_file: config_file)

    expect(transformed_files.size).to eq(2)
    expect(transformed_files).to all(match(/\.llm\.md$/))

    content = File.read(File.join(temp_dir, 'README.llm.md'))
    expect(content).to include('[docs](https://config-test.com/docs.md)')
  end
end
