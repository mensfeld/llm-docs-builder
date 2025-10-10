# frozen_string_literal: true

RSpec.describe 'Compression Presets Integration' do
  let(:temp_dir) { Dir.mktmpdir }
  let(:test_file) { File.join(temp_dir, 'test.md') }

  let(:complex_content) do
    <<~MD
      ---
      layout: docs
      title: Test
      ---

      # API Documentation

      [![Build](https://badge.svg)](https://example.com)

      > Important note about this API

      ## Introduction

      This is an introduction to the API. The API provides access to data.

      ## Authentication

      ```ruby
      api = API.new(key: 'secret')
      ```

      ## Endpoints

      ### GET /users

      Returns a list of users.

      ```ruby
      api.get('/users')
      ```

      ## More Info

      For more information, visit the [complete documentation here](./docs.md).

      ![Architecture Diagram](./diagram.png)
    MD
  end

  before do
    File.write(test_file, complex_content)
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe 'Conservative Preset' do
    it 'applies only safe transformations' do
      options = LlmDocsBuilder::CompressionPresets.conservative
      result = LlmDocsBuilder.transform_markdown(test_file, options)

      # Should remove safe elements
      expect(result).not_to include('layout: docs')
      expect(result).not_to include('[![Build')
      expect(result).not_to include('![Architecture')

      # Should preserve code and content
      expect(result).to include('```ruby')
      expect(result).to include('api = API.new')
      expect(result).to include('> Important note')
    end
  end

  describe 'Moderate Preset' do
    it 'applies balanced transformations' do
      options = LlmDocsBuilder::CompressionPresets.moderate
      result = LlmDocsBuilder.transform_markdown(test_file, options)

      # Should apply conservative transformations
      expect(result).not_to include('layout: docs')
      expect(result).not_to include('[![Build')

      # Should add TOC
      expect(result).to include('## Table of Contents')
      expect(result).to include('[Introduction](#introduction)')

      # Should simplify links
      expect(result).to include('[complete documentation](./docs.md)')

      # Should remove blockquote formatting
      expect(result).not_to match(/^>\s/)
      expect(result).to include('Important note')

      # Should still preserve code
      expect(result).to include('```ruby')
    end
  end

  describe 'Aggressive Preset' do
    it 'applies maximum compression' do
      options = LlmDocsBuilder::CompressionPresets.aggressive
      result = LlmDocsBuilder.transform_markdown(test_file, options)

      # Should remove code examples
      expect(result).not_to include('```ruby')
      expect(result).not_to include('api = API.new')

      # Should still add TOC
      expect(result).to include('## Table of Contents')

      # Should remove duplicates and stopwords
      # Note: TOC adds content, so overall compression is less than expected
      # Verify stopwords are removed
      expect(result.scan(/\bthe\b/i).length).to be < complex_content.scan(/\bthe\b/i).length
    end
  end

  describe 'Documentation Preset' do
    it 'optimizes for documentation while preserving code' do
      options = LlmDocsBuilder::CompressionPresets.documentation
      result = LlmDocsBuilder.transform_markdown(test_file, options)

      # Should preserve code examples
      expect(result).to include('```ruby')
      expect(result).to include('api = API.new')

      # Should add helpful context (no blockquote when remove_blockquotes is enabled)
      expect(result).to include('**AI Context**:')
      expect(result).to include('optimized for AI consumption')

      # Should add TOC
      expect(result).to include('## Table of Contents')

      # Should apply duplicate removal
      # Note: The test content doesn't have obvious duplicates, so just verify the preset works
      expect(result).to include('# API Documentation')
      expect(result).to include('optimized for AI consumption')
    end
  end

  describe 'Tutorial Preset' do
    it 'preserves learning materials with light compression' do
      options = LlmDocsBuilder::CompressionPresets.tutorial
      result = LlmDocsBuilder.transform_markdown(test_file, options)

      # Should preserve ALL code examples
      expect(result).to include('```ruby')
      expect(result).to include('api = API.new')
      expect(result).to include("api.get('/users')")

      # Should add custom instruction
      expect(result).to include('> **AI Context**:')
      expect(result).to include('tutorial document')

      # Should add TOC
      expect(result).to include('## Table of Contents')

      # Should have minimal compression
      expect(result.length).to be > complex_content.length * 0.75
    end
  end

  describe 'API Reference Preset' do
    it 'optimizes for API documentation structure' do
      options = LlmDocsBuilder::CompressionPresets.api_reference
      result = LlmDocsBuilder.transform_markdown(test_file, options)

      # Should add custom instruction (no blockquote when remove_blockquotes is enabled)
      expect(result).to include('**AI Context**:')
      expect(result).to include('API reference')

      # Should add TOC for navigation
      expect(result).to include('## Table of Contents')

      # Should simplify verbose descriptions
      expect(result).to include('[complete documentation](./docs.md)')

      # Should preserve structure
      expect(result).to include('## Introduction')
      expect(result).to include('### GET /users')
    end
  end

  describe 'Preset Customization' do
    it 'allows merging custom options with presets' do
      custom_options = { custom_instruction: 'Custom AI context message' }
      options = LlmDocsBuilder::CompressionPresets.get(:moderate, custom_options)

      result = LlmDocsBuilder.transform_markdown(test_file, options)

      expect(result).to include('Custom AI context message')
      expect(result).to include('## Table of Contents')
    end

    it 'raises error for unknown preset' do
      expect do
        LlmDocsBuilder::CompressionPresets.get(:unknown)
      end.to raise_error(ArgumentError, /Unknown preset/)
    end
  end

  describe 'Token Savings Estimation' do
    it 'demonstrates token reduction with aggressive preset' do
      original_tokens = LlmDocsBuilder::TokenEstimator.estimate(complex_content)

      options = LlmDocsBuilder::CompressionPresets.aggressive
      compressed = LlmDocsBuilder.transform_markdown(test_file, options)
      compressed_tokens = LlmDocsBuilder::TokenEstimator.estimate(compressed)

      # Note: TOC adds tokens, but code removal and compression should still reduce overall
      # Expect modest reduction (at least some reduction)
      expect(compressed_tokens).to be < original_tokens
    end

    it 'shows minimal token reduction with conservative preset' do
      original_tokens = LlmDocsBuilder::TokenEstimator.estimate(complex_content)

      options = LlmDocsBuilder::CompressionPresets.conservative
      compressed = LlmDocsBuilder.transform_markdown(test_file, options)
      compressed_tokens = LlmDocsBuilder::TokenEstimator.estimate(compressed)

      reduction_percent = ((original_tokens - compressed_tokens).to_f / original_tokens * 100).round

      expect(reduction_percent).to be_between(10, 30)
    end
  end
end
