# llms-txt-ruby

[![CI](https://github.com/mensfeld/llms-txt-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/mensfeld/llms-txt-ruby/actions/workflows/ci.yml)

## llms.txt vs MCP: Why Static Documentation Matters

### The Key Difference

**MCP (Model Context Protocol)** provides real-time, dynamic access to systems through APIs. It's perfect for live data, runtime queries, and interactive operations.

**llms.txt** provides static, versioned documentation that travels with your code. It's perfect for understanding codebases, navigating documentation, and providing persistent context.

### Why You Need Both (But llms.txt First)

| Aspect | llms.txt | MCP |
|--------|----------|-----|
| **Setup** | Zero configuration - just a file | Requires server setup and maintenance |
| **Availability** | Always available, works offline | Requires running server |
| **Versioning** | Versioned with your code | Real-time only |
| **Performance** | Instant, no latency | Network/API latency |
| **Context Window** | Optimized for LLM limits | Can overwhelm context |
| **Use Case** | Documentation, code understanding | Live data, tool execution |

### The Problem llms.txt Solves

**Large Language Models are transforming how developers discover and understand projects** - but they struggle with fragmented documentation, broken links, and inconsistent project structures. When an LLM encounters your project (Ruby, Python, JavaScript, Go, or any other technology), it needs clear entry points to understand what your code does, how to use it, and where to find examples.

**MCP can't help with:**
- Understanding your codebase structure when offline
- Providing versioned documentation that matches specific commits
- Working in environments where MCP servers can't run
- Giving LLMs immediate context without API calls
- Documentation that travels with forked/vendored code

**llms.txt excels at:**
- 📚 **Persistent Context** - Documentation that's always there
- 🔄 **Version Aligned** - Docs that match your code version
- 🚀 **Zero Latency** - No API calls, instant access
- 🌍 **Universal** - Works with any LLM, any environment
- 📦 **Portable** - Travels with your code everywhere

## Why This Tool?

This **universal documentation processor** works with **any programming language** through:

### 🌍 Universal Project Analysis
- **YAML Configuration** - Language-agnostic configuration system
- **LLM-Powered Discovery** - AI understands your project regardless of language
- **Pattern Recognition** - Built-in patterns for Python, JavaScript, Go, Rust, Java, C#, PHP, Ruby, and more
- **Docker Support** - Run without Ruby installation via Docker

### 📚 Markdown Processing (Any Technology)
- **Link Expansion** - Convert relative links to absolute URLs
- **Wiki Transformation** - Make existing documentation LLM-navigable  
- **Batch Processing** - Handle entire documentation directories
- **URL Conversion** - Transform HTML URLs to markdown format

---

A universal tool for generating [llms.txt](https://llmstxt.org/) files and transforming documentation for LLM consumption. Works with any programming language through YAML configuration and LLM-powered analysis.

## Features

### Universal Markdown Processing (Any Technology)
- **Link expansion**: Convert relative links in .md files to absolute URLs for any project
- **URL conversion**: Transform HTML URLs to markdown-friendly format
- **Batch processing**: Process entire directories of markdown files from any tech stack
- **Wiki transformation**: Make existing wikis LLM-navigable (Python docs, Node.js guides, Go tutorials, etc.)
- **Cross-platform**: Works with documentation from any programming language or framework

### Universal Project Analysis (Any Language)
- **Multiple analyzers**: README, wikis, examples, changelogs, documentation directories
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


### Production Examples
- **DevOps Teams**: Process deployment documentation and runbooks
- **Engineering Teams**: Make technical specifications LLM-accessible
- **Documentation Teams**: Batch-process large documentation sets
- **AI Tool Integration**: Prepare codebases for Claude Code, GitHub Copilot, and similar tools

## Detailed Features

### Universal Project Analysis (Any Language)
- **README analysis**: Extracts title, description, documentation links
- **Examples analysis**: Finds and categorizes example files
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

### Option 1: Docker (No Ruby Required) 🐳

```bash
# Clone the repository
git clone https://github.com/mensfeld/llms-txt-ruby
cd llms-txt-ruby

# Build the Docker image
docker build -t llms-txt .

# Run for any project (current directory)
./docker-run.sh --no-llm

# Or use docker directly
docker run --rm -v $(pwd):/workspace llms-txt --no-llm
```

### Option 2: Ruby Gem

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

### 🚀 Universal Project Analysis with YAML (NEW!)

Create a `llms-txt.yml` file in your project:

```yaml
# llms-txt.yml - Works with ANY programming language
project:
  name: auto  # Auto-detect from package.json, Cargo.toml, etc.
  description: auto  # Extract from README
  base_url: https://myproject.io

discovery:
  mode: llm  # Use AI to understand your project (or 'pattern' for offline)
  
llm:
  provider: claude  # or openai, or local
  api_key: $ANTHROPIC_API_KEY  # From environment variable

output:
  formats: [llms.txt, llms-full.txt]
```

Then run:
```bash
# With Docker (no Ruby needed)
docker run --rm -v $(pwd):/workspace llms-txt

# Or with Ruby gem
llms-txt

# Or without any config file (auto-detection)
llms-txt --no-llm
```

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

### Universal llms.txt Generation

**Generate llms.txt files for any project:**

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

### Ruby API (for Ruby-based usage)

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

### YAML Configuration (Recommended)

Create `llms-txt.yml` in your project root:

```yaml
# Universal configuration for any programming language
project:
  name: auto  # Auto-detect from package.json, Cargo.toml, go.mod, etc.
  description: auto  # Extract from README
  base_url: https://yourproject.io

discovery:
  mode: hybrid  # llm, pattern, or hybrid
  analyze_code: true
  analyze_docs: true
  
  # Custom file patterns (optional)
  project_files:
    - package.json      # JavaScript
    - Cargo.toml        # Rust  
    - go.mod            # Go
    - pyproject.toml    # Python
    - pom.xml           # Java
  
  example_patterns:
    - examples/**/*
    - samples/**/*
    - demo/**/*

templates:
  use: auto  # auto, simple, comprehensive, or custom
  sections: [Documentation, Examples, Optional]

output:
  formats: [llms.txt]
  include_optional: true
  expand_links: false  # Set to base URL if needed
  convert_urls: false

llm:
  provider: claude  # claude, openai, or local
  api_key: $ANTHROPIC_API_KEY  # Environment variable
  temperature: 0.3
  fallback_to_pattern: true  # Fallback if LLM fails
```

**Language-specific examples:**
- [Python projects](examples/configs/python.yml)
- [JavaScript/Node.js projects](examples/configs/javascript.yml)  
- [Go projects](examples/configs/go.yml)
- [Rust projects](examples/configs/rust.yml)
- [Minimal config](examples/configs/minimal.yml)

### Ruby Configuration (For Ruby-based projects)

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
  config.file_analyzers = %i[readme changelog examples docs wiki]
  
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
wiki_data = LlmsTxt::Analyzers::Wiki.new('.').analyze
puts "Found #{wiki_data[:total_files]} wiki files"
puts "Broken links: #{wiki_data[:link_analysis][:broken_links].size}"
```

## Project Analysis

The tool automatically analyzes various aspects of any project:

- **README files**: Extracts title, description, and documentation links
- **Examples**: Finds example files and categorizes them
- **Changelog**: Tracks version history and release notes
- **Documentation**: Scans docs directories for guides and references
- **Wiki**: Analyzes wiki directories, markdown files, navigation, and link structure

## Example Output

Here's what a generated llms.txt file might look like:

```markdown
# MyAwesomeProject

> MyAwesomeProject is a software library for processing data with advanced algorithms and providing a clean API for developers.

## Documentation

- [API Documentation](https://docs.myproject.io): Complete API reference
- [Getting Started Guide](https://myproject.io/docs/getting_started.md): Quick introduction and basic usage examples
- [Configuration Guide](https://myproject.io/docs/configuration.md): Detailed configuration options

## Examples

- [Basic Usage Examples](https://myproject.io/examples/basic_usage): Simple examples to get started
- [Advanced Patterns](https://myproject.io/examples/advanced_patterns): Complex usage patterns and best practices

## Optional

- [Changelog](https://myproject.io/CHANGELOG.md): Version history and release notes
- [Contributing Guidelines](https://myproject.io/CONTRIBUTING.md): How to contribute to this project
- [License](https://myproject.io/LICENSE): MIT
- [Project Homepage](https://github.com/user/myproject): Main project website
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