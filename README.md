# llms-txt-ruby

> ⚠️ **Work in Progress** - This gem is currently under active development and not yet ready for any use.

A Ruby gem that automatically generates [llms.txt](https://llmstxt.org/) files for Ruby projects using AI. This gem analyzes your Ruby codebase, extracts documentation from YARD comments, README files, and gemspec metadata, then uses a Large Language Model to create a properly formatted llms.txt file following the official specification.

## What is llms.txt?

The llms.txt file is a proposed standard for providing LLM-friendly content on websites. It offers brief background information, guidance, and links to detailed markdown files, helping Large Language Models understand and navigate your project more effectively.

Learn more at [llmstxt.org](https://llmstxt.org/).

## Features

- 🤖 **AI-powered generation**: Uses Claude or GPT models to create natural, comprehensive llms.txt files
- 📚 **YARD integration**: Extracts rich documentation from YARD comments and tags
- 🔧 **Configurable**: Supports multiple LLM providers and customizable options
- 🖥️ **CLI + API**: Use from command line or integrate into your Ruby applications
- 📁 **Project awareness**: Understands Ruby project structure and conventions
- 🎯 **Spec compliant**: Generates files that strictly follow the llms.txt specification

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'llms-txt-ruby'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install llms-txt-ruby
```

## Example Output

Here's what a generated llms.txt file might look like:

```markdown
# MyAwesomeGem

> MyAwesomeGem is a Ruby library for processing data with advanced algorithms and providing a clean API for developers.

This gem provides a comprehensive toolkit for data processing, featuring both synchronous and asynchronous processing capabilities. It includes built-in caching, error handling, and extensive configuration options.

## Documentation

- [Getting Started Guide](docs/getting_started.md): Quick introduction and basic usage examples
- [API Documentation](https://rubydoc.info/gems/my_awesome_gem): Complete API reference
- [Configuration Guide](docs/configuration.md): Detailed configuration options

## Examples

- [Basic Usage Examples](examples/basic_usage.rb): Simple examples to get started
- [Advanced Patterns](examples/advanced_patterns.rb): Complex usage patterns and best practices

## Optional

- [Contributing Guidelines](CONTRIBUTING.md): How to contribute to this project
- [Changelog](CHANGELOG.md): Version history and changes
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

---

Made with ❤️ for the Ruby community
