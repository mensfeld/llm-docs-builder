# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmsTxt::Builders::Template do
  describe 'basic template creation' do
    it 'creates a template with header configuration' do
      template = LlmsTxt::Builders::Template.new do
        header :title, :description
        documentation
        examples
      end

      builder = template.build(title: 'Test Gem', description: 'A test gem')
      result = builder.build

      expect(result).to include('# Test Gem')
      expect(result).to include('> A test gem')
      expect(result).to include('## Documentation')
      expect(result).to include('## Examples')
    end

    it 'applies defaults' do
      template = LlmsTxt::Builders::Template.new do
        header :title, :description
        defaults title: 'Default Title'
        documentation
      end

      builder = template.build(description: 'Custom description')
      result = builder.build

      expect(result).to include('# Default Title')
      expect(result).to include('> Custom description')
    end
  end

  describe 'template customization' do
    it 'allows customization via block' do
      template = LlmsTxt::Builders::Template.new do
        header :title
        documentation
      end

      builder = template.customize(title: 'Custom Title') do |custom|
        custom.section('Extra Section') do |extra|
          extra.link('Extra Link', 'extra.md')
        end
      end

      result = builder.build

      expect(result).to include('# Custom Title')
      expect(result).to include('## Documentation')
      expect(result).to include('## Extra Section')
      expect(result).to include('- [Extra Link](extra.md)')
    end
  end

  describe 'section configuration' do
    it 'applies section blocks' do
      template = LlmsTxt::Builders::Template.new do
        section('Custom Section') do |section|
          section.link('Predefined Link', 'predefined.md')
        end
      end

      builder = template.build
      result = builder.build

      expect(result).to include('## Custom Section')
      expect(result).to include('- [Predefined Link](predefined.md)')
    end
  end
end

RSpec.describe LlmsTxt::Builders::Templates do
  describe '.ruby_gem' do
    it 'creates a ruby gem template' do
      template = LlmsTxt::Builders::Templates.ruby_gem

      builder = template.build(
        title: 'My Gem',
        description: 'A Ruby gem',
        license: 'MIT'
      )
      result = builder.build

      expect(result).to include('# My Gem')
      expect(result).to include('> A Ruby gem')
      expect(result).to include('## Documentation')
      expect(result).to include('## Examples')
      expect(result).to include('## Optional')
    end
  end

  describe '.simple' do
    it 'creates a simple template' do
      template = LlmsTxt::Builders::Templates.simple

      builder = template.build(
        title: 'Simple Project',
        description: 'A simple project'
      )
      result = builder.build

      expect(result).to include('# Simple Project')
      expect(result).to include('> A simple project')
      expect(result).to include('## Documentation')
      expect(result).to include('## Examples')
      expect(result).to include('## Optional')
    end
  end
end

RSpec.describe LlmsTxt do
  describe '.build_from_template' do
    it 'builds from a template' do
      template = LlmsTxt::Builders::Templates.simple

      result = LlmsTxt.build_from_template(template,
                                           title: 'Template Test',
                                           description: 'Testing template building')

      content = result.build
      expect(content).to include('# Template Test')
      expect(content).to include('> Testing template building')
      expect(content).to include('## Documentation')
    end

    it 'returns a DslBuilder instance' do
      template = LlmsTxt::Builders::Templates.simple
      result = LlmsTxt.build_from_template(template, title: 'Test')
      expect(result).to be_a(LlmsTxt::Builders::DslBuilder)
    end
  end
end
