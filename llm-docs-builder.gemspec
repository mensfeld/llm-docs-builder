# frozen_string_literal: true

require_relative 'lib/llm_docs_builder/version'

Gem::Specification.new do |spec|
  spec.name = 'llm-docs-builder'
  spec.version = LlmDocsBuilder::VERSION
  spec.authors = ['Maciej Mensfeld']
  spec.email = %w[maciej@mensfeld.pl]

  spec.summary = 'Build and optimize documentation for LLMs - generate llms.txt, transform markdown, and more'
  spec.description = <<~DESC
    A comprehensive Ruby tool for building and optimizing documentation for Large Language Models.
    Features include: generating llms.txt files from documentation directories with automatic file
    prioritization, transforming individual markdown files by expanding relative links to absolute URLs,
    bulk transforming entire documentation trees with customizable exclusion patterns, comparing content
    sizes to measure context window savings, and serving LLM-optimized documentation. Provides both CLI
    and Ruby API with configuration file support.
  DESC

  spec.homepage = 'https://github.com/mensfeld/llm-docs-builder'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/mensfeld/llm-docs-builder'
  spec.metadata['changelog_uri'] = 'https://github.com/mensfeld/llm-docs-builder/blob/master/CHANGELOG.md'
  spec.metadata['documentation_uri'] = 'https://github.com/mensfeld/llm-docs-builder'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec|test)/}) }

  spec.bindir = 'bin'
  spec.executables = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'nokogiri', '~> 1.17'
  spec.add_dependency 'zeitwerk', '~> 2.6'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.0'
  spec.add_development_dependency 'simplecov', '~> 0.21'
end
