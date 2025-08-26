# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe LlmsTxt::Builders::DslBuilder do
  describe '#build' do
    it 'builds a basic llms.txt structure' do
      builder = LlmsTxt::Builders::DslBuilder.new
      builder.title('My Awesome Gem')
      builder.description('A Ruby library for processing data')

      result = builder.build

      expect(result).to include('# My Awesome Gem')
      expect(result).to include('> A Ruby library for processing data')
    end

    it 'builds sections with links' do
      builder = LlmsTxt::Builders::DslBuilder.new
      builder.title('Test Project')

      builder.section('Documentation') do |docs|
        docs.link('Getting Started', 'docs/start.md', description: 'Quick start guide')
        docs.link('API Reference', 'docs/api.md')
      end

      result = builder.build

      expect(result).to include('## Documentation')
      expect(result).to include('- [Getting Started](docs/start.md): Quick start guide')
      expect(result).to include('- [API Reference](docs/api.md)')
    end

    it 'supports fluent interface' do
      result = LlmsTxt::Builders::DslBuilder.new
                                            .title('Fluent Example')
                                            .description('Testing fluent interface')
                                            .section('Examples') { |ex| ex.link('Basic', 'basic.rb') }
                                            .build

      expect(result).to include('# Fluent Example')
      expect(result).to include('> Testing fluent interface')
      expect(result).to include('## Examples')
      expect(result).to include('- [Basic](basic.rb)')
    end
  end

  describe 'section builders' do
    let(:builder) { LlmsTxt::Builders::DslBuilder.new }

    it 'supports documentation shortcut' do
      builder.documentation do |docs|
        docs.link('Guide', 'guide.md')
      end

      result = builder.build
      expect(result).to include('## Documentation')
      expect(result).to include('- [Guide](guide.md)')
    end

    it 'supports examples shortcut' do
      builder.examples do |ex|
        ex.link('Example 1', 'ex1.rb')
      end

      result = builder.build
      expect(result).to include('## Examples')
      expect(result).to include('- [Example 1](ex1.rb)')
    end

    it 'supports optional shortcut' do
      builder.optional do |opt|
        opt.changelog
        opt.license('MIT')
        opt.homepage('https://example.com')
      end

      result = builder.build
      expect(result).to include('## Optional')
      expect(result).to include('- [Changelog](CHANGELOG.md): Version history and release notes')
      expect(result).to include('- [License](LICENSE): MIT')
      expect(result).to include('- [Homepage](https://example.com): Project homepage')
    end
  end

  describe 'auto-discovery' do
    before do
      # Create temporary files for testing
      @temp_dir = Dir.mktmpdir
      @original_dir = Dir.pwd
      Dir.chdir(@temp_dir)

      Dir.mkdir('examples')
      File.write('examples/basic.rb', "# Basic Usage\n# This shows basic usage\nputs 'hello'")
      File.write('examples/advanced.rb', "# Advanced Example\n# Complex usage patterns\nclass Advanced; end")
    end

    after do
      Dir.chdir(@original_dir)
      FileUtils.rm_rf(@temp_dir)
    end

    it 'auto-discovers example files' do
      builder = LlmsTxt::Builders::DslBuilder.new
      builder.title('Auto Discovery Test')

      builder.examples do |ex|
        ex.auto_discover('examples/**/*.rb', type: :examples)
      end

      result = builder.build

      expect(result).to include('## Examples')
      expect(result).to include('Basic Usage')
      expect(result).to include('Advanced Example')
      expect(result).to include('examples/basic.rb')
      expect(result).to include('examples/advanced.rb')
    end
  end
end

RSpec.describe LlmsTxt do
  describe '.build' do
    it 'provides DSL interface' do
      result = LlmsTxt.build do |llms|
        llms.title 'DSL Test'
        llms.description 'Testing the DSL interface'

        llms.documentation do |docs|
          docs.link 'README', 'README.md'
        end
      end

      content = result.build
      expect(content).to include('# DSL Test')
      expect(content).to include('> Testing the DSL interface')
      expect(content).to include('## Documentation')
      expect(content).to include('- [README](README.md)')
    end

    it 'returns a DslBuilder instance' do
      result = LlmsTxt.build { |llms| llms.title 'Test' }
      expect(result).to be_a(LlmsTxt::Builders::DslBuilder)
    end
  end
end
