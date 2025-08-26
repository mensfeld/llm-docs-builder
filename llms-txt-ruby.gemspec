# frozen_string_literal: true

require_relative 'lib/llms_txt/version'

Gem::Specification.new do |spec|
  spec.name = 'llms-txt-ruby'
  spec.version = LlmsTxt::VERSION
  spec.authors = ['Maciej Mensfeld']
  spec.email = %w[maciej@mensfeld.pl]

  spec.summary = 'Ruby implementation of the llms.txt specification for LLM-friendly content'
  spec.description = <<~DESC
    A Ruby gem that implements the llms.txt specification, providing tools to create and manage
    llms.txt markdown files for websites. These files help Large Language Models understand
    and navigate website content more effectively by providing curated, LLM-friendly information
    in a standardized format.
  DESC

  spec.homepage = 'https://github.com/mensfeld/llms-txt-ruby'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/mensfeld/llms-txt-ruby'
  spec.metadata['changelog_uri'] = 'https://github.com/mensfeld/llms-txt-ruby/blob/main/CHANGELOG.md'
  spec.metadata['documentation_uri'] = 'https://github.com/mensfeld/llms-txt-ruby'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec|test)/}) }

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'thor', '~> 1.0'
  spec.add_dependency 'yard', '~> 0.9'
  spec.add_dependency 'zeitwerk', '~> 2.6'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.0'
  spec.add_development_dependency 'simplecov', '~> 0.21'
end
