# llms-txt-ruby

[![CI](https://github.com/mensfeld/llms-txt-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/mensfeld/llms-txt-ruby/actions/workflows/ci.yml)

A simple Ruby tool for generating [llms.txt](https://llmstxt.org/) files from existing markdown documentation. Transform your docs to be AI-friendly.

## What is llms.txt?

The llms.txt file is a proposed standard for providing LLM-friendly content on websites. It offers brief background information, guidance, and links to detailed markdown files, helping Large Language Models understand and navigate your project more effectively.

Learn more at [llmstxt.org](https://llmstxt.org/).

## What This Tool Does

**Two simple functions:**

1. **Generate llms.txt** - Scan your existing markdown docs and create a properly formatted llms.txt file
2. **Transform markdown** - Make individual markdown files more AI-friendly by expanding relative links and converting URLs

**That's it.** No LLM APIs, no complex configuration, no universal language detection. Just simple, focused functionality.

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

### Generate llms.txt from your docs

```bash
# Generate from current directory
llms-txt generate

# Generate from docs directory
llms-txt generate --docs ./docs

# Generate with base URL for absolute links
llms-txt generate --docs ./docs --base-url https://myproject.io

# Specify output file
llms-txt generate --docs ./docs --output my-llms.txt
```

### Transform markdown files

```bash
# Transform a single file
llms-txt transform README.md --base-url https://myproject.io

# Save to different file
llms-txt transform README.md --base-url https://myproject.io --output README-ai.md

# Convert HTML URLs to markdown
llms-txt transform docs/api.md --convert-urls
```

## CLI Reference

### Commands

```bash
llms-txt generate [options]   # Generate llms.txt from documentation (default)
llms-txt transform [file]     # Transform a markdown file to be AI-friendly
llms-txt parse [file]         # Parse existing llms.txt file
llms-txt validate [file]      # Validate llms.txt file
llms-txt version              # Show version
```

### Options

```bash
-d, --docs PATH          Path to documentation directory or file
-o, --output PATH        Output file path (default: llms.txt)
-u, --base-url URL       Base URL for expanding relative links
    --convert-urls       Convert HTML URLs to markdown format
-t, --title TITLE        Project title (auto-detected if not provided)
    --description DESC   Project description (auto-detected if not provided)
-v, --verbose            Verbose output
-h, --help               Show help message
```

## Ruby API

### Basic Usage

```ruby
require 'llms_txt'

# Generate llms.txt from documentation directory
content = LlmsTxt.generate_from_docs('./docs')

# Generate with options
content = LlmsTxt.generate_from_docs('./docs',
  base_url: 'https://myproject.io',
  title: 'My Project',
  description: 'A great project'
)

# Transform a markdown file
transformed = LlmsTxt.transform_markdown('README.md',
  base_url: 'https://myproject.io',
  convert_urls: true
)

# Parse existing llms.txt
parsed = LlmsTxt.parse('llms.txt')
puts parsed.title
puts parsed.description

# Validate llms.txt content
valid = LlmsTxt.validate(content)
```

## How It Works

### Generation Process

1. **Scan for markdown files** - Finds all `.md` files in specified directory
2. **Extract metadata** - Gets title and description from each file
3. **Prioritize docs** - Orders by importance (README first, then guides, APIs, etc.)
4. **Build llms.txt** - Creates properly formatted output with links and descriptions

### Transformation Process

1. **Expand relative links** - Convert `./docs/api.md` to `https://myproject.io/docs/api.md`
2. **Convert URLs** - Change `.html` links to `.md` for better AI understanding
3. **Preserve content** - No content modification, just link processing

### File Prioritization

When generating llms.txt, files are automatically prioritized:

1. **README files** - Always listed first
2. **Getting Started guides** - Quick start documentation
3. **Guides and tutorials** - Step-by-step content
4. **API references** - Technical documentation
5. **Other files** - Everything else

## Example Output

Given a `docs/` directory with:
- `README.md`
- `getting-started.md`
- `api-reference.md`

Running `llms-txt generate --docs ./docs --base-url https://myproject.io` creates:

```markdown
# My Project

> This is a Ruby library that helps developers build amazing applications with a clean, simple API.

## Documentation

- [README](https://myproject.io/README.md): Complete overview and installation instructions
- [Getting Started](https://myproject.io/getting-started.md): Quick start guide with examples
- [API Reference](https://myproject.io/api-reference.md): Detailed API documentation and method signatures
```

## What's Different

This tool is **intentionally simple**:

- ❌ No LLM API integrations (Claude, OpenAI, etc.)
- ❌ No complex YAML configuration files
- ❌ No universal language detection
- ❌ No project analysis beyond markdown files
- ❌ No template systems or DSLs

- ✅ Just processes your existing markdown docs
- ✅ Simple command-line interface
- ✅ Clean Ruby API
- ✅ Focused on the core problem
- ✅ Zero external dependencies

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mensfeld/llms-txt-ruby.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).