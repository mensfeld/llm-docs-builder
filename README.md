# llm-docs-builder

[![CI](https://github.com/mensfeld/llm-docs-builder/actions/workflows/ci.yml/badge.svg)](
  https://github.com/mensfeld/llm-docs-builder/actions/workflows/ci.yml)

**Optimize your documentation for LLMs and RAG systems. Reduce token consumption by 67-95%.**

llm-docs-builder transforms markdown documentation to be AI-friendly and generates llms.txt files. It normalizes links, removes unnecessary content, and provides compression presets to maximize context window efficiency.

## The Problem

When LLMs fetch documentation, they typically get HTML pages designed for humans - complete with navigation bars, footers, JavaScript, CSS, and other overhead. This wastes 70-90% of your context window on content that doesn't help answer questions.

**Real example from Karafka documentation:**
- Human HTML version: 82.0 KB (~20,500 tokens)
- AI markdown version: 4.1 KB (~1,025 tokens)
- **Result: 95% reduction, 19,475 tokens saved, 20x smaller**

## Quick Start

### Measure Your Current Token Waste

```bash
# Using Docker (no Ruby installation needed)
docker pull mensfeld/llm-docs-builder:latest

# Compare your documentation page
docker run mensfeld/llm-docs-builder compare \
  --url https://yoursite.com/docs/getting-started.html
```

### Transform Your Documentation

```bash
# Single file with compression preset
llm-docs-builder transform --docs README.md --preset moderate

# Bulk transform with custom options
llm-docs-builder bulk-transform --config llm-docs-builder.yml
```

## Installation

### Docker (Recommended)

```bash
docker pull mensfeld/llm-docs-builder:latest
alias llm-docs-builder='docker run -v $(pwd):/workspace mensfeld/llm-docs-builder'
```

### RubyGems

```bash
gem install llm-docs-builder
```

## Features

### 1. Compression Presets

Choose from 6 built-in presets optimized for different use cases:

```ruby
# Conservative (15-25% reduction) - safest
LlmDocsBuilder.transform_markdown('README.md',
  **CompressionPresets.conservative)

# Moderate (30-45% reduction) - balanced
LlmDocsBuilder.transform_markdown('README.md',
  **CompressionPresets.moderate)

# Aggressive (50-70% reduction) - maximum compression
LlmDocsBuilder.transform_markdown('README.md',
  **CompressionPresets.aggressive)

# Documentation (35-50% reduction) - preserves code examples
LlmDocsBuilder.transform_markdown('README.md',
  **CompressionPresets.documentation)

# Tutorial (20% reduction) - minimal compression, preserves all code
LlmDocsBuilder.transform_markdown('README.md',
  **CompressionPresets.tutorial)

# API Reference (40% reduction) - optimized for API docs
LlmDocsBuilder.transform_markdown('README.md',
  **CompressionPresets.api_reference)
```

**What each preset does:**

| Preset | Removes | Adds | Best For |
|--------|---------|------|----------|
| Conservative | Frontmatter, comments, badges, images | - | Public docs with minimal changes |
| Moderate | + Blockquotes | TOC | General documentation |
| Aggressive | + Code, duplicates, stopwords | TOC | Maximum token savings |
| Documentation | Like moderate + duplicates | TOC, AI context | Technical docs with code |
| Tutorial | Like conservative | TOC, AI context | Learning materials |
| API Reference | Like moderate + duplicates | TOC, AI context | API documentation |

### 2. Advanced Compression Options

All features can be used individually:

```yaml
# llm-docs-builder.yml
docs: ./docs
base_url: https://myproject.io
suffix: .llm

# Content removal
remove_frontmatter: true      # Remove YAML/TOML metadata
remove_comments: true          # Remove HTML comments
remove_badges: true            # Remove badge images
remove_images: true            # Remove all images
remove_code_examples: true     # Remove code blocks
remove_blockquotes: true       # Remove blockquote formatting
remove_duplicates: true        # Remove duplicate paragraphs
remove_stopwords: true         # Remove common words (aggressive)

# Content enhancement
generate_toc: true             # Add table of contents
custom_instruction: "AI-optimized docs"  # Add AI context message
simplify_links: true           # Simplify verbose link text
convert_urls: true             # Convert .html to .md
normalize_whitespace: true     # Clean up excessive whitespace

# Exclusions
excludes:
  - "**/private/**"
```

### 3. Measure and Compare

```bash
# Compare what your server sends to humans vs AI
llm-docs-builder compare --url https://yoursite.com/docs/page.html

# Compare remote HTML with local markdown
llm-docs-builder compare \
  --url https://yoursite.com/docs/api.html \
  --file docs/api.md
```

### 4. Generate llms.txt

```bash
# Create standardized documentation index
llm-docs-builder generate --config llm-docs-builder.yml
```

## Configuration

```yaml
# llm-docs-builder.yml
docs: ./docs
base_url: https://myproject.io
title: My Project
description: Brief description
output: llms.txt
suffix: .llm
verbose: false

# Basic options
convert_urls: true
remove_comments: true
remove_badges: true
remove_frontmatter: true
normalize_whitespace: true

# Advanced compression (use presets or configure individually)
remove_code_examples: false
remove_images: true
remove_blockquotes: true
remove_duplicates: true
remove_stopwords: false
simplify_links: true
generate_toc: true
custom_instruction: "This documentation is optimized for AI consumption"

# Exclusions
excludes:
  - "**/private/**"
  - "**/drafts/**"
```

**Configuration precedence:**
1. CLI flags (highest)
2. Config file
3. Defaults

## CLI Commands

```bash
llm-docs-builder compare [options]        # Measure token savings
llm-docs-builder transform [options]      # Transform single file
llm-docs-builder bulk-transform [options] # Transform directory
llm-docs-builder generate [options]       # Generate llms.txt
llm-docs-builder parse [options]          # Parse llms.txt
llm-docs-builder validate [options]       # Validate llms.txt
llm-docs-builder version                  # Show version
```

**Common options:**
```
-c, --config PATH    Configuration file
-d, --docs PATH      Documentation path
-o, --output PATH    Output file
-u, --url URL        URL for comparison
-v, --verbose        Detailed output
```

## Ruby API

```ruby
require 'llm_docs_builder'

# Using presets
transformed = LlmDocsBuilder.transform_markdown('README.md',
  LlmDocsBuilder::CompressionPresets.moderate
)

# Custom options
transformed = LlmDocsBuilder.transform_markdown('README.md',
  base_url: 'https://myproject.io',
  remove_code_examples: true,
  remove_images: true,
  generate_toc: true,
  custom_instruction: 'AI-optimized documentation'
)

# Bulk transform
files = LlmDocsBuilder.bulk_transform('./docs',
  base_url: 'https://myproject.io',
  suffix: '.llm',
  remove_duplicates: true,
  generate_toc: true
)

# Generate llms.txt
content = LlmDocsBuilder.generate_from_docs('./docs',
  base_url: 'https://myproject.io',
  title: 'My Project'
)
```

## Serving Optimized Docs to AI Bots

After using `bulk-transform` with `suffix: .llm`, configure your web server to serve optimized versions to AI bots:

**Apache (.htaccess):**
```apache
SetEnvIf User-Agent "(?i)(openai|anthropic|claude|gpt)" IS_LLM_BOT
RewriteCond %{ENV:IS_LLM_BOT} !^$
RewriteRule ^(.*)\.md$ $1.llm.md [L]
```

**Nginx:**
```nginx
map $http_user_agent $is_llm_bot {
    default 0;
    "~*(?i)(openai|anthropic|claude|gpt)" 1;
}

location ~ ^/docs/(.*)\.md$ {
    if ($is_llm_bot) {
        rewrite ^(.*)\.md$ $1.llm.md last;
    }
}
```

## Real-World Results: Karafka Framework

**Before:** 140+ lines of custom transformation code

**After:** 6 lines of configuration
```yaml
docs: ./online/docs
base_url: https://karafka.io/docs
convert_urls: true
remove_comments: true
remove_badges: true
remove_frontmatter: true
normalize_whitespace: true
suffix: ""  # In-place for build pipeline
```

**Results:**
- 93% average token reduction
- 20-36x smaller files
- Automated via GitHub Actions

## Docker Usage

```bash
# Pull image
docker pull mensfeld/llm-docs-builder:latest

# Compare (no volume needed for remote URLs)
docker run mensfeld/llm-docs-builder compare \
  --url https://yoursite.com/docs

# Transform with volume mount
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder \
  bulk-transform --config llm-docs-builder.yml
```

**CI/CD Example (GitHub Actions):**
```yaml
- name: Optimize documentation
  run: |
    docker run -v ${{ github.workspace }}:/workspace \
      mensfeld/llm-docs-builder bulk-transform --config llm-docs-builder.yml
```

## Compression Examples

**Input markdown:**
```markdown
---
layout: docs
---

# API Documentation

[![Build](badge.svg)](https://ci.com)

> Important: This is a note

[Click here to see the complete API documentation](./api.md)

```ruby
api = API.new
```

![Diagram](./diagram.png)
```

**With `moderate` preset:**
```markdown
# API Documentation

## Table of Contents

- [API Documentation](#api-documentation)

Important: This is a note

[complete API documentation](./api.md)

```ruby
api = API.new
```
```

**Token reduction:** ~30-45%

## FAQ

**Q: Do I need to use llms.txt?**
No. The compare and transform commands work independently.

**Q: Will this change how humans see my docs?**
Not with default `suffix: .llm`. Separate files are served only to AI bots.

**Q: Can I use this in my build pipeline?**
Yes. Use `suffix: ""` for in-place transformation.

**Q: How do I know if it's working?**
Use `llm-docs-builder compare` to measure before and after.

**Q: What about private documentation?**
Use the `excludes` option to skip sensitive files.

## Contributing

Bug reports and pull requests welcome at [github.com/mensfeld/llm-docs-builder](https://github.com/mensfeld/llm-docs-builder).

## License

Available as open source under the [MIT License](https://opensource.org/licenses/MIT).
