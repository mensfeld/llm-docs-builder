# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'tmpdir'

RSpec.describe LlmDocsBuilder do
  it 'has a version number' do
    expect(LlmDocsBuilder::VERSION).not_to be nil
  end

  describe '.generate_from_docs' do
    let(:temp_dir) { Dir.mktmpdir }

    before do
      # Create sample markdown files
      File.write(File.join(temp_dir, 'README.md'), <<~MD)
        # Test Project

        This is a sample project for testing the llm-docs-builder generator.

        ## Features
        - Simple and clean
        - Easy to use
      MD

      File.write(File.join(temp_dir, 'getting-started.md'), <<~MD)
        # Getting Started

        This guide will help you get started with the project.
      MD

      File.write(File.join(temp_dir, 'api.md'), <<~MD)
        # API Reference

        Complete API documentation for developers.
      MD
    end

    after do
      FileUtils.rm_rf(temp_dir)
    end

    it 'generates llms.txt from documentation directory' do
      result = LlmDocsBuilder.generate_from_docs(temp_dir, config_file: '/nonexistent')

      expect(result).to be_a(String)
      expect(result).to include('# Test Project')
      expect(result).to include('## Documentation')
      expect(result).to include('README')
      expect(result).to include('Getting Started')
      expect(result).to include('API Reference')
    end

    it 'generates with base URL' do
      result = LlmDocsBuilder.generate_from_docs(temp_dir, base_url: 'https://example.com')

      expect(result).to include('https://example.com/README.md')
      expect(result).to include('https://example.com/getting-started.md')
    end

    it 'uses custom title and description' do
      result = LlmDocsBuilder.generate_from_docs(
        temp_dir,
        title: 'Custom Title',
        description: 'Custom description'
      )

      expect(result).to include('# Custom Title')
      expect(result).to include('> Custom description')
    end

    it 'works with single file' do
      readme_file = File.join(temp_dir, 'README.md')
      result = LlmDocsBuilder.generate_from_docs(readme_file, config_file: '/nonexistent')

      expect(result).to include('# Test Project')
      expect(result).to include('README')
    end
  end

  describe '.transform_markdown' do
    let(:temp_file) do
      file = Tempfile.new(['test', '.md'])
      file.write(<<~MD)
        # Test Document

        Check out the [API docs](./api.md) and [guide](docs/guide.md).

        Also see our website at https://example.com/docs.html
      MD
      file.close
      file
    end

    after do
      temp_file.unlink
    end

    it 'expands relative links' do
      result = LlmDocsBuilder.transform_markdown(temp_file.path, base_url: 'https://mysite.com')

      expect(result).to include('[API docs](https://mysite.com/api.md)')
      expect(result).to include('[guide](https://mysite.com/docs/guide.md)')
    end

    it 'converts HTML URLs to markdown' do
      result = LlmDocsBuilder.transform_markdown(temp_file.path, convert_urls: true)

      expect(result).to include('https://example.com/docs.md')
    end

    it 'does both transformations' do
      result = LlmDocsBuilder.transform_markdown(
        temp_file.path,
        base_url: 'https://mysite.com',
        convert_urls: true
      )

      expect(result).to include('[API docs](https://mysite.com/api.md)')
      expect(result).to include('https://example.com/docs.md')
    end
  end

  describe '.parse' do
    let(:sample_content) do
      <<~CONTENT
        # Test Project

        > A sample Ruby project for testing

        ## Documentation

        - [API Reference](docs/api.md): Complete API documentation
        - [Getting Started](docs/getting_started.md): Quick start guide

        ## Examples

        - [Basic Usage](examples/basic.rb): Simple usage examples
      CONTENT
    end

    let(:temp_file) do
      file = Tempfile.new('llms.txt')
      file.write(sample_content)
      file.close
      file
    end

    after do
      temp_file.unlink
    end

    it 'parses llms.txt file correctly' do
      parsed = LlmDocsBuilder.parse(temp_file.path)

      expect(parsed.title).to eq('Test Project')
      expect(parsed.description).to eq('A sample Ruby project for testing')
      expect(parsed.documentation_links).to be_an(Array)
      expect(parsed.documentation_links.size).to be >= 1
    end
  end

  describe '.validate' do
    let(:valid_content) do
      <<~CONTENT
        # Valid Project

        > A valid llms.txt file

        ## Documentation

        - [Docs](docs/): Documentation
      CONTENT
    end

    let(:invalid_content) do
      <<~CONTENT
        Invalid file without proper header
      CONTENT
    end

    it 'validates valid content' do
      expect(LlmDocsBuilder.validate(valid_content)).to be true
    end

    it 'rejects invalid content' do
      expect(LlmDocsBuilder.validate(invalid_content)).to be false
    end
  end

  describe 'config file support' do
    let(:temp_dir) { Dir.mktmpdir }
    let(:config_file) { File.join(temp_dir, 'llm-docs-builder.yml') }

    before do
      # Create sample markdown files
      File.write(File.join(temp_dir, 'README.md'), <<~MD)
        # Config Test Project

        This is a test project for config functionality.
      MD

      # Create config file
      File.write(config_file, <<~YAML)
        docs: #{temp_dir}
        base_url: https://config-test.com
        title: Config Title
        description: Config Description
        output: config-output.txt
        convert_urls: true
        verbose: false
      YAML
    end

    after do
      FileUtils.rm_rf(temp_dir)
    end

    describe '.generate_from_docs with config file' do
      it 'uses config file settings' do
        result = LlmDocsBuilder.generate_from_docs(config_file: config_file)

        expect(result).to include('# Config Title')
        expect(result).to include('> Config Description')
        expect(result).to include('https://config-test.com/README.md')
      end

      it 'allows CLI options to override config' do
        result = LlmDocsBuilder.generate_from_docs(config_file: config_file, title: 'Override Title')

        expect(result).to include('# Override Title')
        expect(result).to include('> Config Description') # description not overridden
      end

      it 'supports config-first usage pattern' do
        result = LlmDocsBuilder.generate_from_docs(config_file: config_file)

        expect(result).to include('# Config Title')
        expect(result).to include('https://config-test.com/README.md')
      end
    end

    describe '.transform_markdown with config file' do
      let(:markdown_file) { File.join(temp_dir, 'test.md') }

      before do
        File.write(markdown_file, <<~MD)
          # Test Doc

          See [API](./api.md) and visit https://example.com/page.html
        MD
      end

      it 'uses config file for transformation' do
        result = LlmDocsBuilder.transform_markdown(markdown_file, config_file: config_file)

        expect(result).to include('[API](https://config-test.com/api.md)')
        expect(result).to include('https://example.com/page.md') # convert_urls: true
      end
    end
  end
end
