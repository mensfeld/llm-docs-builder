# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe LlmsTxt do
  it 'has a version number' do
    expect(LlmsTxt::VERSION).not_to be nil
  end

  describe '.configuration' do
    it 'returns a configuration object' do
      expect(LlmsTxt.configuration).to be_a(LlmsTxt::Configuration)
    end

    it 'allows configuration via block' do
      LlmsTxt.configure do |config|
        config.llm_provider = :openai
        config.verbose = true
      end

      expect(LlmsTxt.configuration.llm_provider).to eq(:openai)
      expect(LlmsTxt.configuration.verbose).to be true
    end
  end

  describe '.generate' do
    it 'returns generated content' do
      result = LlmsTxt.generate(no_llm: true, project_root: File.expand_path('..', __dir__))
      expect(result).to be_a(String)
      expect(result).to include('# ')
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
      parsed = LlmsTxt.parse(temp_file.path)

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
      expect(LlmsTxt.validate(valid_content)).to be true
    end

    it 'rejects invalid content' do
      expect(LlmsTxt.validate(invalid_content)).to be false
    end
  end
end
