# llm-docs-builder

[![CI](https://github.com/mensfeld/llm-docs-builder/actions/workflows/ci.yml/badge.svg)](
  https://github.com/mensfeld/llm-docs-builder/actions/workflows/ci.yml)

**Optimize your documentation for LLMs and RAG systems. Reduce token consumption by 67-95%.**

llm-docs-builder transforms markdown documentation to be AI-friendly and generates llms.txt files. It normalizes links, removes unnecessary content, optimizes documents for LLM context windows, and enhances documents for RAG retrieval with hierarchical heading context and metadata.

## The Problem

When LLMs fetch documentation, they typically get HTML pages designed for humans - complete with navigation bars, footers, JavaScript, CSS, and other overhead. This wastes 70-90% of your context window on content that doesn't help answer questions.

**Real example from Karafka documentation:**
- Human HTML version: 104.4 KB (~26,735 tokens)
- AI markdown version: 21.5 KB (~5,496 tokens)
- **Result: 79% reduction, 21,239 tokens saved, 5x smaller**

## Quick Start

### Measure Your Current Token Waste

```bash
# Using Docker (no Ruby installation needed)
docker pull mensfeld/llm-docs-builder:latest

# Compare your documentation page
docker run mensfeld/llm-docs-builder compare \
  --url https://yoursite.com/docs/getting-started.html
```

**Example output:**
```
============================================================
Context Window Comparison
============================================================

Human version:  127.4 KB (~32,620 tokens)
  Source: https://karafka.io/docs/Pro-Virtual-Partitions/ (User-Agent: human)

AI version:     46.3 KB (~11,854 tokens)
  Source: https://karafka.io/docs/Pro-Virtual-Partitions/ (User-Agent: AI)

------------------------------------------------------------
Reduction:      81.1 KB (64%)
Token savings:  20,766 tokens (64%)
Factor:         2.8x smaller
============================================================
```

### Transform Your Documentation

```bash
# Single file
llm-docs-builder transform --docs README.md

# Bulk transform with config
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

### Measure and Compare

```bash
# Compare what your server sends to humans vs AI
llm-docs-builder compare --url https://yoursite.com/docs/page.html

# Compare remote HTML with local markdown
llm-docs-builder compare \
  --url https://yoursite.com/docs/api.html \
  --file docs/api.md
```

### Generate llms.txt

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

# Additional compression options
remove_code_examples: false
remove_images: true
remove_blockquotes: true
remove_duplicates: true
remove_stopwords: false
simplify_links: true
generate_toc: true
custom_instruction: "This documentation is optimized for AI consumption"

# RAG enhancement options
normalize_headings: true          # Add hierarchical context to headings
heading_separator: " / "          # Separator for heading hierarchy
include_metadata: true            # Enable enhanced llms.txt metadata
include_tokens: true              # Include token counts in llms.txt
include_timestamps: true          # Include update timestamps in llms.txt
include_priority: true            # Include priority labels in llms.txt
calculate_compression: false      # Calculate compression ratios (slower)

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

# Transform single file with custom options
transformed = LlmDocsBuilder.transform_markdown(
  'README.md',
  base_url: 'https://myproject.io',
  remove_code_examples: true,
  remove_images: true,
  generate_toc: true,
  custom_instruction: 'AI-optimized documentation'
)

# Bulk transform
files = LlmDocsBuilder.bulk_transform(
  './docs',
  base_url: 'https://myproject.io',
  suffix: '.llm',
  remove_duplicates: true,
  generate_toc: true
)

# Generate llms.txt
content = LlmDocsBuilder.generate_from_docs(
  './docs',
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

**After transformation (with default options):**
```markdown
# API Documentation

[complete API documentation](./api.md)

```ruby
api = API.new
```
```

**Token reduction:** ~40-60% depending on configuration

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

## RAG Enhancement Features

### Heading Normalization

Transform headings to include hierarchical context, making each section self-contained for RAG retrieval:

**Before:**
```markdown
# Configuration
## Consumer Settings
### auto_offset_reset

Controls behavior when no offset exists...
```

**After (with `normalize_headings: true`):**
```markdown
# Configuration
## Configuration / Consumer Settings
### Configuration / Consumer Settings / auto_offset_reset

Controls behavior when no offset exists...
```

**Why this matters for RAG:** When documents are chunked and retrieved independently, each section retains full context. An LLM seeing just the `auto_offset_reset` section knows it's about "Configuration / Consumer Settings / auto_offset_reset" not just generic "auto_offset_reset".

```yaml
# Enable in config
normalize_headings: true
heading_separator: " / "  # Customize separator (default: " / ")
```

### Enhanced llms.txt Metadata

Generate enriched llms.txt files with token counts, timestamps, and priority labels to help AI agents make better decisions:

**Standard llms.txt:**
```markdown
- [Getting Started](https://myproject.io/docs/Getting-Started.md)
- [Configuration](https://myproject.io/docs/Configuration.md)
```

**Enhanced llms.txt (with metadata enabled):**
```markdown
- [Getting Started](https://myproject.io/docs/Getting-Started.md) tokens:450 updated:2025-10-13 priority:high
- [Configuration](https://myproject.io/docs/Configuration.md) tokens:2800 updated:2025-10-12 priority:high
- [Advanced Topics](https://myproject.io/docs/Advanced.md) tokens:5200 updated:2025-09-15 priority:medium
```

**Benefits:**
- AI agents can see token counts → load multiple small docs vs one large doc
- Timestamps help prefer recent documentation
- Priority signals guide which docs to fetch first
- Compression ratios show optimization effectiveness

```yaml
# Enable in config
include_metadata: true      # Master switch
include_tokens: true        # Show token counts
include_timestamps: true    # Show last modified dates
include_priority: true      # Show priority labels (high/medium/low)
calculate_compression: true # Show compression ratios (slower, requires transformation)
```

## Advanced Compression Options

All compression features can be used individually for fine-grained control:

### Content Removal Options

- `remove_frontmatter: true` - Remove YAML/TOML metadata blocks
- `remove_comments: true` - Remove HTML comments (`<!-- ... -->`)
- `remove_badges: true` - Remove badge/shield images (CI badges, version badges, etc.)
- `remove_images: true` - Remove all image syntax
- `remove_code_examples: true` - Remove fenced code blocks, indented code, and inline code
- `remove_blockquotes: true` - Remove blockquote formatting (preserves content)
- `remove_duplicates: true` - Remove duplicate paragraphs using fuzzy matching
- `remove_stopwords: true` - Remove common stopwords from prose (preserves code blocks)

### Content Enhancement Options

- `generate_toc: true` - Generate table of contents from headings with anchor links
- `custom_instruction: "text"` - Inject AI context message at document top
- `simplify_links: true` - Simplify verbose link text (e.g., "Click here to see the docs" → "docs")
- `convert_urls: true` - Convert `.html`/`.htm` URLs to `.md` format
- `normalize_whitespace: true` - Reduce excessive blank lines and remove trailing whitespace

### Example Usage

```ruby
# Fine-grained control
LlmDocsBuilder.transform_markdown(
  'README.md',
  remove_frontmatter: true,
  remove_badges: true,
  remove_images: true,
  simplify_links: true,
  generate_toc: true,
  normalize_whitespace: true
)
```

Or configure via YAML:

```yaml
# llm-docs-builder.yml
docs: ./docs
base_url: https://myproject.io
suffix: .llm

# Pick exactly what you need
remove_frontmatter: true
remove_comments: true
remove_badges: true
remove_images: true
simplify_links: true
generate_toc: true
normalize_whitespace: true
```

## Contributing

Bug reports and pull requests welcome at [github.com/mensfeld/llm-docs-builder](https://github.com/mensfeld/llm-docs-builder).

## License

Available as open source under the [MIT License](https://opensource.org/licenses/MIT).
