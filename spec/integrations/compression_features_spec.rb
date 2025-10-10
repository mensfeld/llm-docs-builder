# frozen_string_literal: true

RSpec.describe 'Compression Features Integration' do
  let(:temp_dir) { Dir.mktmpdir }
  let(:test_file) { File.join(temp_dir, 'test.md') }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe 'Token Optimization Features' do
    let(:sample_content) do
      <<~MD
        ---
        layout: post
        title: Test
        ---

        # Test Documentation

        [![Build Status](https://travis-ci.org/test.svg)](https://travis-ci.org/test)

        > This is a blockquote with important information

        ## Introduction

        This is a test document. Check out the [documentation here](./docs.md).

        ## Code Examples

        ```ruby
        def hello
          puts "world"
        end
        ```

        Inline code: `puts "hello"`

        ## Images

        ![Test Image](./images/test.png)

        ## More Content

        This is a test document. This is a test document.
      MD
    end

    before do
      File.write(test_file, sample_content)
    end

    it 'removes code examples effectively' do
      result = LlmDocsBuilder.transform_markdown(test_file, remove_code_examples: true)

      expect(result).not_to include('def hello')
      expect(result).not_to include('puts "world"')
      expect(result).not_to include('`puts "hello"`')
      expect(result).to include('# Test Documentation')
    end

    it 'removes images while preserving content' do
      result = LlmDocsBuilder.transform_markdown(test_file, remove_images: true)

      expect(result).not_to include('![Test Image]')
      expect(result).to include('# Test Documentation')
      expect(result).to include('## Images')
    end

    it 'removes blockquotes formatting' do
      result = LlmDocsBuilder.transform_markdown(test_file, remove_blockquotes: true)

      expect(result).not_to match(/^>\s/)
      expect(result).to include('This is a blockquote')
    end

    it 'simplifies link text' do
      content_with_verbose_links = <<~MD
        # Doc

        Click here to read the API documentation
        [See the complete guide here](./guide.md)
        [Read more about configuration](./config.md)
      MD

      File.write(test_file, content_with_verbose_links)
      result = LlmDocsBuilder.transform_markdown(test_file, simplify_links: true)

      expect(result).to include('[complete guide](./guide.md)')
      expect(result).to include('[configuration](./config.md)')
    end

    it 'generates table of contents' do
      result = LlmDocsBuilder.transform_markdown(test_file, generate_toc: true)

      expect(result).to include('## Table of Contents')
      expect(result).to include('- [Introduction](#introduction)')
      expect(result).to include('- [Code Examples](#code-examples)')
    end

    it 'injects custom instructions' do
      instruction = 'This documentation is optimized for AI consumption'
      result = LlmDocsBuilder.transform_markdown(test_file, custom_instruction: instruction)

      expect(result).to include('> **AI Context**:')
      expect(result).to include(instruction)
    end

    it 'combines multiple transformations' do
      result = LlmDocsBuilder.transform_markdown(test_file,
        remove_frontmatter: true,
        remove_badges: true,
        remove_code_examples: true,
        remove_images: true,
        remove_blockquotes: true,
        simplify_links: true,
        generate_toc: true,
        normalize_whitespace: true,
        custom_instruction: 'AI-optimized documentation'
      )

      # Removed elements
      expect(result).not_to include('layout: post')
      expect(result).not_to include('[![Build')
      expect(result).not_to include('def hello')
      expect(result).not_to include('![Test Image]')
      expect(result).not_to match(/^>\s/)

      # Added elements
      expect(result).to include('## Table of Contents')
      expect(result).to include('**AI Context**: AI-optimized documentation')

      # Preserved content
      expect(result).to include('# Test Documentation')
      expect(result).to include('## Introduction')
    end
  end

  describe 'Advanced Compression' do
    let(:duplicate_content) do
      <<~MD
        # Guide

        ## Section 1

        This is important information about the topic.

        ## Section 2

        This is important information about the topic.

        ## Section 3

        Here is different content that should be preserved.
      MD
    end

    it 'removes duplicate paragraphs' do
      File.write(test_file, duplicate_content)
      result = LlmDocsBuilder.transform_markdown(test_file, remove_duplicates: true)

      # Should only appear once
      occurrences = result.scan(/This is important information/).length
      expect(occurrences).to eq(1)
      expect(result).to include('Here is different content')
    end

    it 'removes stopwords while preserving technical content' do
      content_with_stopwords = <<~MD
        # API

        This is a simple guide to the API. The API provides access to the data.

        ```ruby
        # Code should be preserved
        api = API.new
        ```
      MD

      File.write(test_file, content_with_stopwords)
      result = LlmDocsBuilder.transform_markdown(test_file,
        remove_stopwords: true,
        remove_code_examples: false
      )

      # Stopwords should be removed from prose
      expect(result.scan(/\bthe\b/i).length).to be < content_with_stopwords.scan(/\bthe\b/i).length

      # But code blocks should be preserved
      expect(result).to include('```ruby')
      expect(result).to include('api = API.new')
    end
  end

  describe 'Bulk Transformation with Compression' do
    before do
      # Create multiple files
      File.write(File.join(temp_dir, 'doc1.md'), "# Doc 1\n\nContent here")
      File.write(File.join(temp_dir, 'doc2.md'), "# Doc 2\n\n```ruby\ncode\n```")
      File.write(File.join(temp_dir, 'doc3.md'), "# Doc 3\n\n![Image](test.png)")
    end

    it 'applies compression to all files in bulk' do
      transformed = LlmDocsBuilder.bulk_transform(temp_dir,
        remove_code_examples: true,
        remove_images: true,
        generate_toc: true,
        suffix: '.ai'
      )

      expect(transformed.length).to eq(3)
      expect(File.exist?(File.join(temp_dir, 'doc1.ai.md'))).to be true
      expect(File.exist?(File.join(temp_dir, 'doc2.ai.md'))).to be true
      expect(File.exist?(File.join(temp_dir, 'doc3.ai.md'))).to be true

      # Check transformations were applied
      doc2_content = File.read(File.join(temp_dir, 'doc2.ai.md'))
      expect(doc2_content).not_to include('```ruby')

      doc3_content = File.read(File.join(temp_dir, 'doc3.ai.md'))
      expect(doc3_content).not_to include('![Image]')
    end
  end
end
