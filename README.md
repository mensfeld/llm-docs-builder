# llms-txt-ruby

[![CI](https://github.com/mensfeld/llms-txt-ruby/actions/workflows/ci.yml/badge.svg)](
  https://github.com/mensfeld/llms-txt-ruby/actions/workflows/ci.yml)

A Ruby tool for generating [llms.txt](https://llmstxt.org/) files from existing markdown
documentation. Transform your docs to be AI-friendly.

## What is llms.txt?

The llms.txt file is a proposed standard for providing LLM-friendly content on websites. It
offers brief background information, guidance, and links to detailed markdown files, helping
Large Language Models understand and navigate your project more effectively.

Learn more at [llmstxt.org](https://llmstxt.org/).

## What This Tool Does

This library converts existing human-first documentation into LLM-friendly formats:

1. **Generates llms.txt** - Transforms your existing markdown documentation into a structured
   overview that helps LLMs understand your project's layout and find relevant information
2. **Transforms markdown** - Converts individual markdown files from human-readable format to
   AI-optimized format by expanding relative links to absolute URLs and normalizing link
   structures
3. **Bulk transforms** - Processes all markdown files in a directory recursively, creating
   LLM-friendly versions alongside originals with customizable exclusion patterns

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

### Option 1: Using Config File (Recommended)

Create a `llms-txt.yml` file in your project root:

```yaml
# llms-txt.yml
docs: ./docs
base_url: https://myproject.io
title: My Awesome Project
description: A Ruby library that helps developers build amazing applications
output: llms.txt
convert_urls: true
verbose: false
```

Then simply run:

```bash
llms-txt generate
```

### Option 2: Using CLI Only

```bash
# Generate from docs directory
llms-txt generate --docs ./docs

# Transform a single file
llms-txt transform README.md

# Transform all markdown files in directory
llms-txt bulk-transform --docs ./docs

# Use custom config file
llms-txt generate --config my-config.yml
```

## CLI Reference

### Commands

```bash
llms-txt generate [options]       # Generate llms.txt from documentation (default)
llms-txt transform [file]         # Transform a markdown file to be AI-friendly
llms-txt bulk-transform [options] # Transform all markdown files in directory
llms-txt parse [file]             # Parse existing llms.txt file
llms-txt validate [file]          # Validate llms.txt file
llms-txt version                  # Show version
```

### Options

```bash
-c, --config PATH        Configuration file path (default: llms-txt.yml)
-d, --docs PATH          Path to documentation directory or file
-o, --output PATH        Output file path
-v, --verbose            Verbose output
-h, --help               Show help message
```

*For advanced options like base_url, title, description, and convert_urls, use a config file.*

## Configuration File

The recommended way to use llms-txt is with a `llms-txt.yml` config file. This allows you to:

- ✅ Store all your settings in one place
- ✅ Version control your llms.txt configuration
- ✅ Avoid typing long CLI commands repeatedly
- ✅ Share configuration across team members

### Config File Options

```yaml
# Path to documentation directory or file
docs: ./docs

# Base URL for expanding relative links (optional)
base_url: https://myproject.io

# Project information (optional - auto-detected if not provided)
title: My Project Name
description: Brief description of what your project does

# Output file (optional, default: llms.txt)
output: llms.txt

# Transformation options (optional)
convert_urls: true   # Convert .html links to .md
verbose: false       # Enable verbose output
```

The config file will be automatically found if named:
- `llms-txt.yml`
- `llms-txt.yaml`
- `.llms-txt.yml`

## Bulk Transformation

The `bulk-transform` command processes all markdown files in a directory recursively, creating
AI-friendly versions alongside the originals. This is perfect for transforming entire
documentation trees.

### Key Features

- **Recursive processing** - Finds and transforms all `.md` files in nested directories
- **Preserves structure** - Maintains your existing directory layout
- **Exclusion patterns** - Skip files/directories using glob patterns
- **Custom suffixes** - Choose how transformed files are named
- **LLM optimizations** - Expands relative links, converts HTML URLs, etc.

### Usage

```bash
# Transform all files with default settings
llms-txt bulk-transform --docs ./wiki

# Using config file (recommended for complex setups)
llms-txt bulk-transform --config karafka-config.yml
```

### Example Config for Bulk Transformation

```yaml
# karafka-config.yml
docs: ./wiki
base_url: https://karafka.io
suffix: .llm
convert_urls: true
excludes:
  - "**/private/**"      # Skip private directories
  - "**/draft-*.md"      # Skip draft files
  - "**/old-docs/**"     # Skip legacy documentation
```

### Example Output

With the config above, these files:
```
wiki/
├── Home.md
├── getting-started.md
├── api/
│   ├── consumers.md
│   └── producers.md
└── private/
    └── internal.md
```

Become:
```
wiki/
├── Home.md
├── Home.llm.md          ← AI-friendly version
├── getting-started.md
├── getting-started.llm.md
├── api/
│   ├── consumers.md
│   ├── consumers.llm.md
│   ├── producers.md
│   └── producers.llm.md
└── private/
    └── internal.md      ← Excluded, no .llm.md version
```

## Ruby API

### Basic Usage

```ruby
require 'llms_txt'

# Option 1: Using config file (recommended)
content = LlmsTxt.generate_from_docs(config_file: 'llms-txt.yml')

# Option 2: Direct options (overrides config)
content = LlmsTxt.generate_from_docs('./docs',
  base_url: 'https://myproject.io',
  title: 'My Project',
  description: 'A great project'
)

# Option 3: Mix config file with overrides
content = LlmsTxt.generate_from_docs('./docs',
  config_file: 'my-config.yml',
  title: 'Override Title'  # This overrides config file title
)

# Transform markdown with config
transformed = LlmsTxt.transform_markdown('README.md',
  config_file: 'llms-txt.yml'
)

# Transform with direct options
transformed = LlmsTxt.transform_markdown('README.md',
  base_url: 'https://myproject.io',
  convert_urls: true
)

# Bulk transform all files in directory
transformed_files = LlmsTxt.bulk_transform('./wiki',
  base_url: 'https://karafka.io',
  suffix: '.llm',
  excludes: ['**/private/**', '**/draft-*.md']
)
puts "Transformed #{transformed_files.size} files"

# Bulk transform with config file
transformed_files = LlmsTxt.bulk_transform('./wiki',
  config_file: 'karafka-config.yml'
)

# Parse and validate (unchanged)
parsed = LlmsTxt.parse('llms.txt')
puts parsed.title
puts parsed.description

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
- [API Reference](https://myproject.io/api-reference.md): Detailed API documentation and method
  signatures
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mensfeld/llms-txt-ruby.

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
