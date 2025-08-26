# llms-txt-ruby

[![CI](https://github.com/mensfeld/llms-txt-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/mensfeld/llms-txt-ruby/actions/workflows/ci.yml)

## Why llms.txt and LLM-Friendly Documentation Matter

**Large Language Models are transforming how developers discover and understand projects** - but they struggle with fragmented documentation, broken links, and inconsistent project structures. When an LLM encounters your project (Ruby, Python, JavaScript, Go, or any other technology), it needs clear entry points to understand what your code does, how to use it, and where to find examples.

**The problem:** LLMs waste time parsing scattered READMEs, guessing at project structure, and following broken documentation links. Your amazing project might be invisible to AI-powered development tools.

**The solution:** [llms.txt](https://llmstxt.org/) - a proposed standard that creates a single, LLM-optimized file describing your project. Think of it as a "sitemap for AI" that helps language models quickly understand and navigate any codebase.

## Why This Tool?

This Ruby gem provides **two powerful capabilities for any project**:

1. **Universal Markdown Processing** - Transform existing documentation, wikis, and markdown files to be LLM-friendly across any technology stack
2. **Ruby Project Analysis** - Generate llms.txt files by intelligently analyzing Ruby codebases

**Key benefits:**
- 🌍 **Works with any technology** - Process documentation from Python, JavaScript, Go, Rust, Java projects  
- 🔗 **Link processing** - Converts relative links to absolute URLs so LLMs can navigate properly
- 📚 **Wiki transformation** - Make existing wikis and documentation LLM-navigable
- 🤖 **AI-ready documentation** - Help Claude, GPT, and other LLMs understand your projects instantly
- 🚀 **Future-proof your documentation** - As AI coding assistants become standard, ensure your docs are discoverable

---

A Ruby-based tool that generates [llms.txt](https://llmstxt.org/) files for Ruby projects and transforms markdown documentation for LLM consumption across any technology stack. Process wikis, documentation directories, and markdown files to make them AI-navigable.

## Features

### Universal Markdown Processing (Any Technology)
- **Link expansion**: Convert relative links in .md files to absolute URLs for any project
- **URL conversion**: Transform HTML URLs to markdown-friendly format
- **Batch processing**: Process entire directories of markdown files from any tech stack
- **Wiki transformation**: Make existing wikis LLM-navigable (Python docs, Node.js guides, Go tutorials, etc.)
- **Cross-platform**: Works with documentation from any programming language or framework

### Ruby Project Analysis (Ruby-Specific)
- **Multiple analyzers**: README, gemspec, YARD docs, wikis, examples, changelogs, documentation directories
- **AI integration**: Works with Claude (Anthropic) or OpenAI, with local template fallback
- **Validation**: Built-in llms.txt specification validation
- **Parser**: Parse existing llms.txt files and convert to XML

### General
- **CLI and Ruby API**: Command-line tool and programmatic interface  
- **Zero dependencies on external services**: Works completely offline in template mode

## What is llms.txt?

The llms.txt file is a proposed standard for providing LLM-friendly content on websites. It offers brief background information, guidance, and links to detailed markdown files, helping Large Language Models understand and navigate your project more effectively.

Learn more at [llmstxt.org](https://llmstxt.org/).

## Use Cases

### For Any Technology Stack
- **Documentation Migration**: Make existing wikis and docs LLM-navigable (Python, JavaScript, Go, Rust, Java, C#, etc.)
- **Internal Documentation**: Process company wikis and internal docs for AI consumption
- **Open Source Projects**: Prepare documentation from any language for LLM tools
- **API Documentation**: Convert REST API docs, GraphQL schemas, or any markdown-based docs
- **Knowledge Bases**: Transform Notion exports, GitBook content, or wiki exports

### For Ruby Projects Specifically  
- **Gem Documentation**: Auto-generate llms.txt for RubyGems with intelligent analysis
- **Rails Applications**: Create AI-friendly documentation for Rails apps
- **Library Maintenance**: Keep documentation current with automated analysis

### Production Examples
- **DevOps Teams**: Process deployment documentation and runbooks
- **Engineering Teams**: Make technical specifications LLM-accessible
- **Documentation Teams**: Batch-process large documentation sets
- **AI Tool Integration**: Prepare codebases for Claude Code, GitHub Copilot, and similar tools

## Detailed Features

### Ruby Project Analysis (Ruby-Specific)
- **README analysis**: Extracts title, description, documentation links
- **Gemspec analysis**: Pulls metadata, dependencies, URIs
- **YARD documentation**: Processes API docs, examples, coverage stats
- **Examples analysis**: Finds and categorizes Ruby example files
- **Documentation**: Scans docs directories for guides and references  
- **Changelog analysis**: Tracks version history and release notes

### Universal Markdown Processing (Any Technology)
- **Wiki analysis**: Processes wiki directories, navigation files, link structure
- **Link processing**: Converts relative links to absolute URLs
- **URL transformation**: Makes HTML URLs markdown-friendly
- **Batch processing**: Handles entire directory trees of markdown files
- **Cross-platform compatibility**: Works with any project structure

### Generation Options
- **AI-powered**: Use Claude or OpenAI models for intelligent content generation
- **Template mode**: Generate without API keys using project analysis
- **Automatic fallback**: Switches to template mode if LLM provider fails

### Link Processing
- **Link expansion**: Convert relative links to absolute URLs
- **URL conversion**: Transform HTML URLs to markdown format
- **Broken link detection**: Identify and report broken internal links
- **Navigation extraction**: Process wiki navigation and index files

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

## Quick Start

### Universal Markdown Processing (Works with Any Project)

**Process documentation from any technology stack:**

```bash
# Process Python project documentation  
cd /path/to/python-project
llms-txt --expand-links https://python-project.io --convert-urls --directory ./docs --no-llm

# Process Node.js project wiki
cd /path/to/nodejs-project  
llms-txt --expand-links https://nodejs-project.com --directory ./wiki --no-llm

# Process Go project documentation
cd /path/to/go-project
llms-txt --expand-links https://go-project.dev --convert-urls --directory ./documentation --no-llm

# Process any markdown files in current directory
llms-txt --expand-links https://myproject.io --convert-urls --no-llm
```

### Ruby-Specific llms.txt Generation

**Generate llms.txt files for Ruby projects:**

```bash
# Template mode (no API key needed)
llms-txt --no-llm

# With AI for smarter content generation
export ANTHROPIC_API_KEY="your-api-key"  
llms-txt --provider claude --verbose
```

**Parse and validate:**

```bash  
llms-txt parse llms.txt --verbose
llms-txt validate llms.txt
```

### Ruby API

```ruby
require 'llms_txt'

# Quick generation (template mode)
LlmsTxt.configure do |config|
  config.llm_provider = :local
  config.verbose = true
end

content = LlmsTxt.generate
puts content

# Parse existing file
parsed = LlmsTxt.parse('llms.txt')
puts "Title: #{parsed.title}"
puts "Description: #{parsed.description}"

# Validate content
valid = LlmsTxt.validate(content)
puts valid ? "✓ Valid" : "✗ Invalid"
```

## Usage

### CLI Commands

```bash
# Generate llms.txt (default command)
llms-txt [options]
llms-txt generate [options]

# Parse existing llms.txt file  
llms-txt parse [file] [options]

# Validate llms.txt file
llms-txt validate [file] [options]

# Show version
llms-txt version
```

### CLI Options

```bash
Options:
  -o, --output PATH       Output file path (default: llms.txt)
  -p, --provider PROVIDER LLM provider: claude, openai, local (default: claude)
  -k, --api-key KEY       API key for LLM provider
  -m, --model MODEL       LLM model to use
      --no-llm            Generate template without LLM (local mode)
      --no-optional       Exclude optional section
  -d, --directory PATH    Project directory (default: current directory)
  -c, --config PATH       Configuration file path
      --expand-links URL  Expand relative links to absolute URLs using base URL
      --convert-urls      Convert HTML URLs to markdown-friendly URLs
  -v, --verbose           Verbose output
  -h, --help              Show help message
```

### Configuration

Create a configuration file (e.g., `llms_txt_config.rb`):

```ruby
LlmsTxt.configure do |config|
  # LLM Provider Settings
  config.llm_provider = :claude # :claude, :openai, or :local
  config.api_key = ENV['ANTHROPIC_API_KEY']
  config.model = 'claude-3-opus-20240229'
  config.temperature = 0.3
  config.max_tokens = 4096

  # Output Settings
  config.output_path = 'llms.txt'
  config.include_optional = true
  config.verbose = false

  # Analysis Settings
  config.file_analyzers = %i[readme gemspec yard changelog examples docs wiki]
  
  # File Patterns
  config.exclude_patterns = %w[
    vendor/**/*
    node_modules/**/*
    tmp/**/*
    coverage/**/*
    .git/**/*
  ]
end
```

Then use it:

```bash
llms-txt --config llms_txt_config.rb
```

### LLM Providers

#### Claude (Anthropic)

```ruby
LlmsTxt.configure do |config|
  config.llm_provider = :claude
  config.api_key = ENV['ANTHROPIC_API_KEY']
  config.model = 'claude-3-opus-20240229' # or claude-3-sonnet-20240229
end
```

#### OpenAI

```ruby
LlmsTxt.configure do |config|
  config.llm_provider = :openai
  config.api_key = ENV['OPENAI_API_KEY']
  config.model = 'gpt-4-turbo-preview' # or gpt-3.5-turbo
end
```

#### Local/Template Mode

```ruby
LlmsTxt.configure do |config|
  config.llm_provider = :local
  # No API key required
end
```

### Universal Documentation Processing

Process documentation from any programming language or framework:

#### Cross-Technology Examples

**Python Projects:**
```bash
# Django project documentation
cd django-project
llms-txt --expand-links https://mydjango.app --directory ./docs --no-llm

# Flask API documentation  
cd flask-api
llms-txt --expand-links https://api.myflask.com --convert-urls --directory ./documentation --no-llm
```

**JavaScript/Node.js Projects:**
```bash
# React documentation
cd react-app
llms-txt --expand-links https://myreact.app --directory ./docs --no-llm

# Express.js API docs
cd express-api  
llms-txt --expand-links https://api.express.com --convert-urls --directory ./wiki --no-llm
```

**Go Projects:**
```bash
# Go microservice documentation
cd go-service
llms-txt --expand-links https://go-service.dev --directory ./docs --no-llm
```

**Any Technology:**
```bash
# Process any project's markdown files
cd /any/project/with/docs
llms-txt --expand-links https://yourproject.com --convert-urls --no-llm
```

### Advanced Documentation Processing

The gem includes powerful features for processing wikis and documentation inspired by production deployment scripts:

#### Link Expansion for LLMs

Convert relative links to absolute URLs so LLMs can navigate properly:

```bash
llms-txt --expand-links https://myproject.io --no-llm
```

#### URL Conversion for Documentation Sites

Convert HTML URLs to markdown-friendly URLs:

```bash
llms-txt --convert-urls --no-llm
```

#### Wiki Analysis

The gem automatically analyzes:
- Wiki directories (`wiki/`, `docs/`, `documentation/`)
- Markdown files with internal/external link analysis
- Navigation structure and index files
- Broken link detection
- Content organization and word counts

### Ruby API Examples

#### Basic Generation

```ruby
require 'llms_txt'

# Generate for current directory
content = LlmsTxt.generate

# Generate for specific directory
content = LlmsTxt.generate(project_root: '/path/to/project')

# Generate with custom output
content = LlmsTxt.generate(
  output: 'my_llms.txt',
  include_optional: false
)
```

#### Parsing and Validation

```ruby
# Parse existing file
parsed = LlmsTxt.parse('llms.txt')

puts parsed.title         # "My Project"
puts parsed.description   # "Project description"
puts parsed.documentation_links.size  # 3
puts parsed.example_links.size       # 2

# Convert to XML for LLM consumption
xml_content = parsed.to_xml
File.write('llms_context.xml', xml_content)

# Validate content
validator = LlmsTxt::Validator.new(content)
if validator.valid?
  puts "✓ Valid llms.txt file"
else
  puts "Validation errors:"
  validator.errors.each { |error| puts "  - #{error}" }
end
```

#### Advanced Configuration

```ruby
LlmsTxt.configure do |config|
  config.llm_provider = :claude
  config.api_key = ENV['ANTHROPIC_API_KEY']
  config.verbose = true
  
  # Customize analyzers
  config.file_analyzers = %i[readme gemspec examples wiki]
  
  # Custom exclusions
  config.exclude_patterns += ['my_secret_dir/**/*']
  
  # YARD settings
  config.yard_options = { markup: :markdown }
end

# Generate with custom options and link processing
content = LlmsTxt.generate(
  project_root: Dir.pwd,
  no_llm: false,
  include_optional: true,
  expand_links: 'https://myproject.io',
  convert_urls: true
)
```

#### Link Processing Utilities

Use the link processing utilities directly:

```ruby
require 'llms_txt'

# Expand relative links to absolute URLs
expander = LlmsTxt::Utils::MarkdownLinkExpander.new(
  'path/to/file.md', 
  'https://mysite.com'
)
expanded_content = expander.to_s

# Convert HTML URLs to markdown-friendly URLs  
converter = LlmsTxt::Utils::MarkdownUrlConverter.new('path/to/file.md')
converted_content = converter.to_s

# Analyze wiki structure
wiki_data = LlmsTxt::Analyzers::WikiAnalyzer.new('.').analyze
puts "Found #{wiki_data[:total_files]} wiki files"
puts "Broken links: #{wiki_data[:link_analysis][:broken_links].size}"
```

## Project Analysis

The gem automatically analyzes various aspects of your Ruby project:

- **README files**: Extracts title, description, and documentation links
- **Gemspec**: Pulls metadata like name, version, description, and URIs
- **YARD documentation**: Processes API documentation and code examples
- **Examples**: Finds example files and categorizes them
- **Changelog**: Tracks version history and release notes
- **Documentation**: Scans docs directories for guides and references
- **Wiki**: Analyzes wiki directories, markdown files, navigation, and link structure

## Example Output

Here's what a generated llms.txt file might look like:

```markdown
# MyAwesomeGem

> MyAwesomeGem is a Ruby library for processing data with advanced algorithms and providing a clean API for developers.

## Documentation

- [API Documentation](https://rubydoc.info/gems/my_awesome_gem): Complete API reference
- [Getting Started Guide](https://llms-txt-ruby.io/docs/getting_started.md): Quick introduction and basic usage examples
- [Configuration Guide](https://llms-txt-ruby.io/docs/configuration.md): Detailed configuration options

## Examples

- [Basic Usage Examples](https://llms-txt-ruby.io/examples/basic_usage.rb): Simple examples to get started
- [Advanced Patterns](https://llms-txt-ruby.io/examples/advanced_patterns.rb): Complex usage patterns and best practices

## Optional

- [Changelog](https://llms-txt-ruby.io/CHANGELOG.md): Version history and release notes
- [Contributing Guidelines](https://llms-txt-ruby.io/CONTRIBUTING.md): How to contribute to this project
- [License](https://llms-txt-ruby.io/LICENSE): MIT
- [Project Homepage](https://github.com/user/my_awesome_gem): Main project website
```

## Development

After checking out the repo, run:

```bash
bin/setup
bundle install
bundle exec rspec    # Run tests
bundle exec rubocop  # Run linter
```

To test the CLI locally:

```bash
ruby -Ilib exe/llms-txt --no-llm --verbose
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mensfeld/llms-txt-ruby.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).