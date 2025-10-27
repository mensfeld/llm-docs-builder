# frozen_string_literal: true

require 'llm_docs_builder/parser'
require 'tempfile'
require 'fileutils'

RSpec.describe LlmDocsBuilder::Parser do
  let(:temp_file) { Tempfile.new(['llms', '.txt']) }

  after do
    temp_file.close
    temp_file.unlink
  end

  describe '#parse' do
    it 'parses basic llms.txt with title and description' do
      content = <<~TXT
        # My Project

        > A brief description of my project

        ## Documentation

        - [README](README.md): Main documentation
        - [Guide](guide.md): User guide
      TXT

      File.write(temp_file.path, content)
      parser = described_class.new(temp_file.path)
      parsed = parser.parse

      expect(parsed.title).to eq('My Project')
      expect(parsed.description).to eq('A brief description of my project')
      expect(parsed.documentation_links).to be_an(Array)
      expect(parsed.documentation_links.length).to eq(2)
    end

    it 'parses links without descriptions (spec-compliant optional descriptions)' do
      content = <<~TXT
        # My Project

        ## Documentation

        - [README](README.md)
        - [Guide](guide.md)
        - [API](api.md)
      TXT

      File.write(temp_file.path, content)
      parser = described_class.new(temp_file.path)
      parsed = parser.parse

      expect(parsed.documentation_links.length).to eq(3)
      expect(parsed.documentation_links[0][:title]).to eq('README')
      expect(parsed.documentation_links[0][:url]).to eq('README.md')
      expect(parsed.documentation_links[0][:description]).to eq('')
    end

    it 'parses links with descriptions containing metadata in parentheses' do
      content = <<~TXT
        # My Project

        ## Documentation

        - [Getting Started](start.md): Quick start guide (tokens:450, updated:2025-10-13)
        - [API Reference](api.md): Complete API docs (tokens:2800, updated:2025-10-12, priority:high)
      TXT

      File.write(temp_file.path, content)
      parser = described_class.new(temp_file.path)
      parsed = parser.parse

      expect(parsed.documentation_links.length).to eq(2)
      expect(parsed.documentation_links[0][:title]).to eq('Getting Started')
      expect(parsed.documentation_links[0][:description]).to include('Quick start guide')
      expect(parsed.documentation_links[0][:description]).to include('tokens:450')
    end

    it 'parses links with metadata but no description' do
      content = <<~TXT
        # My Project

        ## Documentation

        - [API](api.md): (tokens:1200, updated:2025-10-12)
      TXT

      File.write(temp_file.path, content)
      parser = described_class.new(temp_file.path)
      parsed = parser.parse

      expect(parsed.documentation_links.length).to eq(1)
      expect(parsed.documentation_links[0][:title]).to eq('API')
      expect(parsed.documentation_links[0][:description]).to include('tokens:1200')
    end

    it 'parses multiple sections (Documentation, Examples, Optional)' do
      content = <<~TXT
        # My Project

        > Project description

        ## Documentation

        - [README](README.md): Main docs
        - [Getting Started](start.md): Get started

        ## Examples

        - [Basic Example](examples/basic.md): Simple example
        - [Advanced Example](examples/advanced.md): Complex example

        ## Optional

        - [Advanced Topics](advanced.md): Deep dive
        - [Reference](reference.md): API reference
      TXT

      File.write(temp_file.path, content)
      parser = described_class.new(temp_file.path)
      parsed = parser.parse

      expect(parsed.documentation_links.length).to eq(2)
      expect(parsed.example_links.length).to eq(2)
      expect(parsed.optional_links.length).to eq(2)

      expect(parsed.documentation_links[0][:title]).to eq('README')
      expect(parsed.example_links[0][:title]).to eq('Basic Example')
      expect(parsed.optional_links[0][:title]).to eq('Advanced Topics')
    end

    it 'handles mixed links with and without descriptions' do
      content = <<~TXT
        # My Project

        ## Documentation

        - [README](README.md): Main documentation
        - [Guide](guide.md)
        - [API](api.md): API reference (tokens:3000)
        - [Examples](examples.md)
      TXT

      File.write(temp_file.path, content)
      parser = described_class.new(temp_file.path)
      parsed = parser.parse

      expect(parsed.documentation_links.length).to eq(4)
      expect(parsed.documentation_links[0][:description]).to eq('Main documentation')
      expect(parsed.documentation_links[1][:description]).to eq('')
      expect(parsed.documentation_links[2][:description]).to include('API reference')
      expect(parsed.documentation_links[3][:description]).to eq('')
    end

    it 'parses title without description' do
      content = <<~TXT
        # My Project

        ## Documentation

        - [README](README.md): Main documentation
      TXT

      File.write(temp_file.path, content)
      parser = described_class.new(temp_file.path)
      parsed = parser.parse

      expect(parsed.title).to eq('My Project')
      expect(parsed.description).to be_nil
    end

    it 'handles empty sections gracefully' do
      content = <<~TXT
        # My Project

        > Project description
      TXT

      File.write(temp_file.path, content)
      parser = described_class.new(temp_file.path)
      parsed = parser.parse

      expect(parsed.title).to eq('My Project')
      expect(parsed.description).to eq('Project description')
      expect(parsed.documentation_links).to eq([])
      expect(parsed.example_links).to eq([])
      expect(parsed.optional_links).to eq([])
    end
  end
end
