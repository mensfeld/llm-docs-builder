# frozen_string_literal: true

require_relative 'lib/llms-txt/version'

Gem::Specification.new do |spec|
  spec.name = 'llms-txt-ruby'
  spec.version = LLMsTxt::VERSION
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

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split('\x0').reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
end
