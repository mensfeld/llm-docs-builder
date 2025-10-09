# llm-docs-builder

[![CI](https://github.com/mensfeld/llm-docs-builder/actions/workflows/ci.yml/badge.svg)](
  https://github.com/mensfeld/llm-docs-builder/actions/workflows/ci.yml)

**Optimize your documentation for LLMs and RAG systems. Reduce token consumption by 67-95%.**

llm-docs-builder normalizes markdown documentation to be AI-friendly and generates llms.txt files. Transform relative links to absolute URLs, measure token savings when serving markdown vs HTML, and create standardized documentation indexes that help LLMs navigate your project.

## The Problem

When LLMs fetch documentation, they typically get HTML pages designed for humans - complete with navigation bars, footers, JavaScript, CSS, and other overhead. This wastes 70-90% of your context window on content that doesn't help answer questions.

**Real example from Karafka documentation:**
- Human HTML version: 82.0 KB (~20,500 tokens)
- AI markdown version: 4.1 KB (~1,025 tokens)
- **Result: 95% reduction, 19,475 tokens saved, 20x smaller**

With GPT-4's pricing at $2.50 per million input tokens, that's real money saved on every API call. More importantly, you can fit 30x more actual documentation into the same context window.

## What This Tool Does

llm-docs-builder helps you optimize markdown documentation for AI consumption:

1. **Measure Savings** - Compare what your server sends to humans (HTML) vs AI bots (markdown) to quantify context window reduction
2. **Transform Markdown** - Normalize your markdown files with absolute links and consistent URL formats for better LLM navigation
3. **Generate llms.txt** - Create standardized documentation indexes following the [llms.txt](https://llmstxt.org/) specification
4. **Serve Efficiently** - Configure your server to automatically serve transformed markdown to AI bots while humans get HTML

## Quick Start

### Measure Your Current Token Waste

Before making any changes, see how much you could save:

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

Human version:  45.2 KB (~11,300 tokens)
  Source: https://yoursite.com/docs/page.html (User-Agent: human)

AI version:     12.8 KB (~3,200 tokens)
  Source: https://yoursite.com/docs/page.html (User-Agent: AI)

------------------------------------------------------------
Reduction:      32.4 KB (72%)
Token savings:  8,100 tokens (72%)
Factor:         3.5x smaller
============================================================
```

This single command shows you the potential ROI before you invest any time in optimization.

### Real-World Results

**[Karafka Framework Documentation](https://karafka.io/docs)** (10 pages analyzed):

| Page | Human HTML | AI Markdown | Reduction | Tokens Saved | Factor |
|------|-----------|-------------|-----------|--------------|---------|
| Getting Started | 82.0 KB | 4.1 KB | 95% | ~19,475 | 20.1x |
| Configuration | 86.3 KB | 7.1 KB | 92% | ~19,800 | 12.1x |
| Routing | 93.6 KB | 14.7 KB | 84% | ~19,725 | 6.4x |
| Deployment | 122.1 KB | 33.3 KB | 73% | ~22,200 | 3.7x |
| Producing Messages | 87.7 KB | 8.3 KB | 91% | ~19,850 | 10.6x |
| Consuming Messages | 105.3 KB | 21.3 KB | 80% | ~21,000 | 4.9x |
| Web UI Getting Started | 109.3 KB | 21.5 KB | 80% | ~21,950 | 5.1x |
| Active Job | 88.7 KB | 8.8 KB | 90% | ~19,975 | 10.1x |
| Monitoring and Logging | 120.7 KB | 32.5 KB | 73% | ~22,050 | 3.7x |
| Error Handling | 93.8 KB | 13.1 KB | 86% | ~20,175 | 7.2x |

**Average: 83% reduction, ~20,620 tokens saved per page, 8.4x smaller files**

For a typical RAG system making 1,000 documentation queries per day:
- **Before**: ~990 KB per day (~247,500 tokens) × 1,000 queries = ~247.5M tokens/day
- **After**: ~165 KB per day (~41,250 tokens) × 1,000 queries = ~41.25M tokens/day
- **Savings**: 83% reduction = ~206.25M tokens saved per day

At GPT-4 pricing ($2.50/M input tokens), that's approximately **$500/day or $183,000/year saved** on a documentation site with moderate traffic.

## Installation

### Option 1: Docker (Recommended)

No Ruby installation required. Perfect for CI/CD and quick usage:

```bash
# Pull the image
docker pull mensfeld/llm-docs-builder:latest

# Create an alias for convenience
alias llm-docs-builder='docker run -v $(pwd):/workspace mensfeld/llm-docs-builder'

# Use like a native command
llm-docs-builder compare --url https://yoursite.com/docs
```

Multi-architecture support (amd64/arm64), ~50MB image size.

### Option 2: RubyGems

For Ruby developers or when you need the Ruby API:

```bash
gem install llm-docs-builder
```

Or add to your Gemfile:

```ruby
gem 'llm-docs-builder'
```

## Core Features

### 1. Compare and Measure (The "Before You Start" Tool)

Quantify exactly how much context window you're wasting:

```bash
# Compare what your server sends to humans vs AI bots
llm-docs-builder compare --url https://yoursite.com/docs/page.html

# Compare remote HTML with your local markdown
llm-docs-builder compare \
  --url https://yoursite.com/docs/api.html \
  --file docs/api.md

# Verbose mode for debugging
llm-docs-builder compare --url https://example.com/docs --verbose
```

**Why this matters:**
- Validates that optimizations actually work
- Quantifies ROI before you invest time
- Monitors ongoing effectiveness
- Provides concrete metrics for stakeholders

### 2. Transform Markdown (The Normalizer)

Normalize your markdown documentation to be LLM-friendly:

**Single file transformation:**
```bash
# Expand relative links to absolute URLs
llm-docs-builder transform \
  --docs README.md \
  --config llm-docs-builder.yml
```

**Bulk transformation - two modes:**

**a) Separate files (default)** - Creates `.llm.md` versions alongside originals:
```yaml
# llm-docs-builder.yml
docs: ./docs
base_url: https://myproject.io
suffix: .llm                 # Creates README.llm.md alongside README.md
convert_urls: true           # .html → .md
remove_comments: true        # Remove HTML comments
remove_badges: true          # Remove badge/shield images
remove_frontmatter: true     # Remove YAML/TOML frontmatter
normalize_whitespace: true   # Clean up excessive blank lines
```

```bash
llm-docs-builder bulk-transform --config llm-docs-builder.yml
```

Result:
```
docs/
├── README.md          ← Original (for humans)
├── README.llm.md      ← Optimized (for AI)
├── api.md
└── api.llm.md
```

**b) In-place transformation** - Overwrites originals (for build pipelines):
```yaml
# llm-docs-builder.yml
docs: ./docs
base_url: https://myproject.io
suffix: ""                   # Transforms in-place
convert_urls: true           # Convert .html to .md
remove_comments: true        # Remove HTML comments
remove_badges: true          # Remove badge/shield images
remove_frontmatter: true     # Remove YAML/TOML frontmatter
normalize_whitespace: true   # Clean up excessive blank lines
excludes:
  - "**/private/**"
```

```bash
llm-docs-builder bulk-transform --config llm-docs-builder.yml
```

Perfect for CI/CD where you transform docs before deployment.

**What gets normalized:**
- **Links**: Relative → Absolute URLs (`./api.md` → `https://yoursite.com/api.md`)
- **URLs**: HTML → Markdown format (`.html` → `.md`)
- **Comments**: HTML comments removed (`<!-- ... -->`)
- **Badges**: Shield/badge images removed (CI badges, version badges, etc.)
- **Frontmatter**: YAML/TOML metadata removed (Jekyll, Hugo, etc.)
- **Whitespace**: Excessive blank lines reduced (3+ → 2 max)
- Clean markdown structure preserved
- No content modification, just intelligent cleanup

### 3. Generate llms.txt (The Standard)

Create a standardized documentation index following the [llms.txt](https://llmstxt.org/) specification:

```yaml
# llm-docs-builder.yml
docs: ./docs
base_url: https://myproject.io
title: My Project
description: A library that does amazing things
output: llms.txt
```

```bash
llm-docs-builder generate --config llm-docs-builder.yml
```

**Generated output:**
```markdown
# My Project

> A library that does amazing things

## Documentation

- [README](https://myproject.io/README.md): Complete overview and installation
- [Getting Started](https://myproject.io/getting-started.md): Quick start guide
- [API Reference](https://myproject.io/api-reference.md): Detailed API documentation
```

**Smart prioritization:**
1. README files (always first)
2. Getting started guides
3. Tutorials and guides
4. API references
5. Other documentation

The llms.txt file serves as an efficient entry point for AI systems to understand your project structure.

### 4. Serve to AI Bots (The Deployment)

After using `bulk-transform` with `suffix: .llm`, configure your web server to automatically serve optimized versions to AI bots:

**Apache (.htaccess):**
```apache
# Detect AI bots
SetEnvIf User-Agent "(?i)(openai|anthropic|claude|gpt|chatgpt)" IS_LLM_BOT
SetEnvIf User-Agent "(?i)(perplexity|gemini|copilot|bard)" IS_LLM_BOT

# Serve .llm.md to AI, .md to humans
RewriteEngine On
RewriteCond %{ENV:IS_LLM_BOT} !^$
RewriteCond %{REQUEST_URI} ^/docs/.*\.md$ [NC]
RewriteRule ^(.*)\.md$ $1.llm.md [L]
```

**Nginx:**
```nginx
map $http_user_agent $is_llm_bot {
    default 0;
    "~*(?i)(openai|anthropic|claude|gpt)" 1;
    "~*(?i)(perplexity|gemini|copilot)" 1;
}

location ~ ^/docs/(.*)\.md$ {
    if ($is_llm_bot) {
        rewrite ^(.*)\.md$ $1.llm.md last;
    }
}
```

**Cloudflare Workers:**
```javascript
const isLLMBot = /openai|anthropic|claude|gpt|perplexity/i.test(userAgent);
if (isLLMBot && url.pathname.startsWith('/docs/')) {
  url.pathname = url.pathname.replace(/\.md$/, '.llm.md');
}
```

**Result**: AI systems automatically get optimized versions, humans get the original. No manual switching, no duplicate URLs.

## Configuration

All commands support both config files and CLI flags. Config files are recommended for consistency:

```yaml
# llm-docs-builder.yml
docs: ./docs
base_url: https://myproject.io
title: My Project
description: Brief description
output: llms.txt
convert_urls: true
remove_comments: true
remove_badges: true
remove_frontmatter: true
normalize_whitespace: true
suffix: .llm
verbose: false
excludes:
  - "**/private/**"
  - "**/drafts/**"
```

**Configuration precedence:**
1. CLI flags (highest priority)
2. Config file values
3. Defaults

**Example of overriding:**
```bash
# Uses config file but overrides title
llm-docs-builder generate --config llm-docs-builder.yml --title "Override Title"
```

## Docker Usage

All CLI commands work in Docker with the same syntax:

```bash
# Basic pattern
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder [command] [options]

# Examples
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder generate --docs ./docs
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder transform --docs README.md
docker run mensfeld/llm-docs-builder compare --url https://example.com/docs
```

**CI/CD Integration:**

GitHub Actions:
```yaml
- name: Generate llms.txt
  run: |
    docker run -v ${{ github.workspace }}:/workspace \
      mensfeld/llm-docs-builder generate --config llm-docs-builder.yml
```

GitLab CI:
```yaml
generate-llms:
  image: mensfeld/llm-docs-builder:latest
  script:
    - llm-docs-builder generate --docs ./docs
```

See [Docker Usage](#detailed-docker-usage) section below for comprehensive examples.

## Ruby API

For programmatic usage:

```ruby
require 'llm_docs_builder'

# Using config file
content = LlmDocsBuilder.generate_from_docs(config_file: 'llm-docs-builder.yml')

# Direct options
content = LlmDocsBuilder.generate_from_docs('./docs',
  base_url: 'https://myproject.io',
  title: 'My Project'
)

# Transform markdown
transformed = LlmDocsBuilder.transform_markdown('README.md',
  base_url: 'https://myproject.io',
  convert_urls: true,
  remove_comments: true,
  remove_badges: true,
  remove_frontmatter: true,
  normalize_whitespace: true
)

# Bulk transform
files = LlmDocsBuilder.bulk_transform('./docs',
  base_url: 'https://myproject.io',
  suffix: '.llm',
  remove_comments: true,
  remove_badges: true,
  remove_frontmatter: true,
  normalize_whitespace: true,
  excludes: ['**/private/**']
)

# In-place transformation
files = LlmDocsBuilder.bulk_transform('./docs',
  suffix: '',  # Empty for in-place
  base_url: 'https://myproject.io',
  remove_comments: true,
  remove_badges: true,
  remove_frontmatter: true,
  normalize_whitespace: true
)
```

## Real-World Case Study: Karafka Framework

The [Karafka framework](https://github.com/karafka/karafka) processes millions of Kafka messages daily and maintains extensive documentation. Before llm-docs-builder:

- **140+ lines of custom Ruby code** for link expansion and URL normalization
- Manual maintenance of transformation logic
- No way to measure optimization effectiveness

**After implementing llm-docs-builder:**

```yaml
# llm-docs-builder.yml
docs: ./online/docs
base_url: https://karafka.io/docs
convert_urls: true
remove_comments: true
remove_badges: true
remove_frontmatter: true
normalize_whitespace: true
suffix: ""  # In-place transformation for build pipeline
excludes:
  - "**/Enterprise-License-Setup/**"
```

```bash
# In their deployment script
llm-docs-builder bulk-transform --config llm-docs-builder.yml
```

**Results:**
- **140 lines of code → 6 lines of config**
- **93% average token reduction** across all documentation
- **Quantifiable savings** via the compare command
- **Automated daily deployments** via GitHub Actions

The compare command revealed that their documentation was consuming 20-36x more tokens than necessary for AI systems. After optimization, RAG queries became dramatically more efficient.

## CLI Reference

```bash
llm-docs-builder compare [options]        # Measure token savings (start here!)
llm-docs-builder transform [options]      # Transform single markdown file
llm-docs-builder bulk-transform [options] # Transform entire documentation tree
llm-docs-builder generate [options]       # Generate llms.txt index
llm-docs-builder parse [options]          # Parse existing llms.txt
llm-docs-builder validate [options]       # Validate llms.txt format
llm-docs-builder version                  # Show version
```

**Common options:**
```
-c, --config PATH    Configuration file (default: llm-docs-builder.yml)
-d, --docs PATH      Documentation directory or file
-o, --output PATH    Output file path
-u, --url URL        URL for comparison
-f, --file PATH      Local file for comparison
-v, --verbose        Detailed output
-h, --help           Show help
```

For advanced options (base_url, title, suffix, excludes, convert_urls), use a config file.

## Why This Matters for RAG Systems

Retrieval-Augmented Generation (RAG) systems fetch documentation to answer questions. Every byte of overhead in those documents:

1. **Costs money** - More tokens = higher API costs
2. **Reduces capacity** - Less room for actual documentation in context window
3. **Slows responses** - More tokens to process = longer response times
4. **Degrades quality** - Navigation noise can confuse the model

llm-docs-builder addresses all four issues by transforming markdown to be AI-friendly and enabling your server to automatically serve it to AI bots while humans get HTML.

**The JavaScript Problem:**

Many documentation sites rely on JavaScript for rendering. AI crawlers typically don't execute JavaScript, so they either:
- Get incomplete content
- Get server-side rendered HTML (bloated with framework overhead)
- Fail entirely

By detecting AI bots and serving them clean markdown instead of HTML, you sidestep this problem entirely.

## Configuration Reference

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `docs` | String | `./docs` | Documentation directory or file |
| `base_url` | String | - | Base URL for absolute links (e.g., `https://myproject.io`) |
| `title` | String | Auto-detected | Project title |
| `description` | String | Auto-detected | Project description |
| `output` | String | `llms.txt` | Output filename for llms.txt generation |
| `convert_urls` | Boolean | `false` | Convert `.html`/`.htm` to `.md` |
| `remove_comments` | Boolean | `false` | Remove HTML comments (`<!-- ... -->`) |
| `remove_badges` | Boolean | `false` | Remove badge/shield images (CI, version, etc.) |
| `remove_frontmatter` | Boolean | `false` | Remove YAML/TOML frontmatter (Jekyll, Hugo) |
| `normalize_whitespace` | Boolean | `false` | Normalize excessive blank lines and trailing spaces |
| `suffix` | String | `.llm` | Suffix for transformed files (use `""` for in-place) |
| `excludes` | Array | `[]` | Glob patterns to exclude |
| `verbose` | Boolean | `false` | Enable detailed output |

## Detailed Docker Usage

### Installation and Setup

```bash
# Pull from Docker Hub
docker pull mensfeld/llm-docs-builder:latest

# Or from GitHub Container Registry
docker pull ghcr.io/mensfeld/llm-docs-builder:latest

# Create an alias for convenience
alias llm-docs-builder='docker run -v $(pwd):/workspace mensfeld/llm-docs-builder'
```

### Common Commands

**Compare (no volume mount needed for remote URLs):**
```bash
docker run mensfeld/llm-docs-builder compare \
  --url https://karafka.io/docs/Getting-Started/

# With local file
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder compare \
  --url https://example.com/page.html \
  --file docs/page.md
```

**Generate llms.txt:**
```bash
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder \
  generate --docs ./docs --output llms.txt
```

**Transform single file:**
```bash
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder \
  transform --docs README.md --config llm-docs-builder.yml
```

**Bulk transform:**
```bash
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder \
  bulk-transform --config llm-docs-builder.yml
```

**Parse and validate:**
```bash
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder \
  parse --docs llms.txt --verbose

docker run -v $(pwd):/workspace mensfeld/llm-docs-builder \
  validate --docs llms.txt
```

### CI/CD Examples

**GitHub Actions:**
```yaml
jobs:
  optimize-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Transform documentation
        run: |
          docker run -v ${{ github.workspace }}:/workspace \
            mensfeld/llm-docs-builder bulk-transform --config llm-docs-builder.yml
      - name: Measure savings
        run: |
          docker run mensfeld/llm-docs-builder \
            compare --url https://yoursite.com/docs/main.html
```

**GitLab CI:**
```yaml
optimize-docs:
  image: mensfeld/llm-docs-builder:latest
  script:
    - llm-docs-builder bulk-transform --docs ./docs
    - llm-docs-builder compare --url https://yoursite.com/docs
```

**Jenkins:**
```groovy
stage('Optimize Documentation') {
    steps {
        sh '''
            docker run -v ${WORKSPACE}:/workspace \
              mensfeld/llm-docs-builder bulk-transform --config llm-docs-builder.yml
        '''
    }
}
```

### Version Pinning

```bash
# Use specific version
docker run mensfeld/llm-docs-builder:0.3.0 version

# Use major version (gets latest patch)
docker run mensfeld/llm-docs-builder:0 version

# Always latest
docker run mensfeld/llm-docs-builder:latest version
```

### Platform-Specific Usage

**Windows PowerShell:**
```powershell
docker run -v ${PWD}:/workspace mensfeld/llm-docs-builder generate --docs ./docs
```

**Windows Command Prompt:**
```cmd
docker run -v %cd%:/workspace mensfeld/llm-docs-builder generate --docs ./docs
```

**macOS/Linux:**
```bash
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder generate --docs ./docs
```

## About llms.txt Standard

The [llms.txt specification](https://llmstxt.org/) is a proposed standard for providing LLM-friendly content. It defines a structured format that helps AI systems:

- Quickly understand project structure
- Find relevant documentation efficiently
- Navigate complex documentation hierarchies
- Access clean, markdown-formatted content

llm-docs-builder generates llms.txt files automatically by:
1. Scanning your documentation directory
2. Extracting titles and descriptions from markdown files
3. Prioritizing content by importance (README first, then guides, APIs, etc.)
4. Formatting everything according to the specification

The llms.txt file serves as an efficient entry point, but the real token savings come from serving optimized markdown for each individual documentation page.

## How It Works

**Generation Process:**
1. Scan directory for `.md` files
2. Extract title (first H1) and description (first paragraph)
3. Prioritize by importance (README → Getting Started → Guides → API → Other)
4. Build formatted llms.txt with links and descriptions

**Transformation Process:**
1. Remove frontmatter (YAML/TOML metadata)
2. Expand relative links to absolute URLs
3. Convert `.html` URLs to `.md`
4. Remove HTML comments
5. Remove badge/shield images
6. Normalize excessive whitespace
7. Write to new file or overwrite in-place

**Comparison Process:**
1. Fetch URL with human User-Agent (or read local file)
2. Fetch same URL with AI bot User-Agent
3. Calculate size difference and reduction percentage
4. Estimate token counts using character-based heuristic
5. Display human-readable comparison results with byte and token savings

**Token Estimation:**
The tool uses a simple but effective heuristic for estimating token counts: **~4 characters per token**. This approximation works well for English documentation and provides reasonable estimates without requiring external tokenizer dependencies. While not as precise as OpenAI's tiktoken, it's accurate enough (±10-15%) for understanding context window savings and making optimization decisions.

## FAQ

**Q: Do I need to use llms.txt to benefit from this tool?**

No. The compare and transform commands provide value independently. Many users start with `compare` to measure savings, then use `bulk-transform` to normalize their markdown files, and may never generate an llms.txt file.

**Q: Will this change how humans see my documentation?**

Not if you use the default `suffix: .llm` mode. This creates separate `.llm.md` files served only to AI bots. Your original files remain unchanged for human visitors.

**Q: Can I use this in my build pipeline?**

Yes. Use `suffix: ""` for in-place transformation. The Karafka framework does this - they transform their markdown as part of their deployment process.

**Q: How do I know if it's working?**

Use the `compare` command to measure before and after. It shows exact byte counts, reduction percentages, and compression factors.

**Q: Does this work with static site generators?**

Yes. You can transform markdown files before your static site generator processes them, or serve separate `.llm.md` versions alongside your generated HTML.

**Q: What about private/internal documentation?**

Use the `excludes` option to skip sensitive files:
```yaml
excludes:
  - "**/private/**"
  - "**/internal/**"
```

**Q: Can I customize the AI bot detection?**

Yes. The web server examples show the User-Agent patterns. You can add or remove patterns based on which AI systems you want to support.

## Contributing

Bug reports and pull requests welcome at [github.com/mensfeld/llm-docs-builder](https://github.com/mensfeld/llm-docs-builder).

## License

Available as open source under the [MIT License](https://opensource.org/licenses/MIT).
