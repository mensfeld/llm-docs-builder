# llm-docs-builder

[![CI](https://github.com/mensfeld/llm-docs-builder/actions/workflows/ci.yml/badge.svg)](
  https://github.com/mensfeld/llm-docs-builder/actions/workflows/ci.yml)

A Ruby tool for building and optimizing documentation for Large Language Models. Generate [llms.txt](https://llmstxt.org/) files, transform markdown, compare content sizes, and more.
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
   LLM-friendly versions alongside originals (or transforming in-place) with customizable exclusion patterns

## Installation

### Option 1: Using Docker (Recommended for Non-Ruby Users)

Docker allows you to use llm-docs-builder without installing Ruby or any gems. Perfect for CI/CD, scripts, or quick usage:

```bash
# Pull the latest image
docker pull mensfeld/llm-docs-builder:latest

# Or use GitHub Container Registry
docker pull ghcr.io/mensfeld/llm-docs-builder:latest
```

The image is multi-architecture (amd64/arm64) and only ~50MB in size.

**Quick example:**
```bash
# Generate llms.txt from your docs directory
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder generate --docs ./docs

# Compare pages
docker run mensfeld/llm-docs-builder compare --url https://karafka.io/docs/Getting-Started/
```

See [Docker Usage](#docker-usage) section below for detailed examples.

### Option 2: Using RubyGems

Add this line to your application's Gemfile:

```ruby
gem 'llm-docs-builder'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install llm-docs-builder
```

## Quick Start

### Option 1: Using Config File (Recommended)

Create a `llm-docs-builder.yml` file in your project root:

```yaml
# llm-docs-builder.yml
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
llm-docs-builder generate
```

### Option 2: Using CLI Only

```bash
# Generate from docs directory
llm-docs-builder generate --docs ./docs

# Transform a single file
llm-docs-builder transform --docs README.md

# Transform all markdown files in directory
llm-docs-builder bulk-transform --docs ./docs

# Use custom config file
llm-docs-builder generate --config my-config.yml
```

## Docker Usage

Docker provides a convenient way to use llm-docs-builder without installing Ruby. All CLI commands work exactly the same way, just prefix them with the Docker run command.

### Basic Pattern

```bash
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder [command] [options]
```

The `-v $(pwd):/workspace` flag mounts your current directory into the container, allowing the tool to access your files.

### Common Commands

**Generate llms.txt:**
```bash
# From docs directory
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder generate --docs ./docs

# With config file
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder generate --config llm-docs-builder.yml

# Specify output location
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder generate --docs ./wiki --output my-llms.txt
```

**Transform markdown files:**
```bash
# Transform single file
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder transform --docs README.md --output README.llm.md

# Transform with config
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder transform --docs docs/guide.md --config llm-docs-builder.yml
```

**Bulk transform:**
```bash
# Transform all markdown files in directory
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder bulk-transform --docs ./docs

# Transform with config file
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder bulk-transform --config llm-docs-builder.yml

# Verbose output
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder bulk-transform --docs ./wiki --verbose
```

**Compare content sizes:**
```bash
# Compare remote versions (no volume mount needed)
docker run mensfeld/llm-docs-builder compare --url https://karafka.io/docs/Getting-Started/

# Compare remote with local file
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder compare \
  --url https://example.com/docs/page.html \
  --file docs/page.md
```

**Parse and validate:**
```bash
# Parse llms.txt
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder parse --docs llms.txt --verbose

# Validate llms.txt
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder validate --docs llms.txt
```

**Show version and help:**
```bash
# Show version
docker run mensfeld/llm-docs-builder version

# Show help
docker run mensfeld/llm-docs-builder --help
```

### Using Aliases for Convenience

Add this to your `.bashrc` or `.zshrc`:

```bash
alias llm-docs-builder='docker run -v $(pwd):/workspace mensfeld/llm-docs-builder'
```

Then use it like a native command:

```bash
llm-docs-builder generate --docs ./docs
llm-docs-builder transform --docs README.md
llm-docs-builder compare --url https://example.com/docs
```

### CI/CD Integration

**GitHub Actions:**
```yaml
- name: Generate llms.txt
  run: |
    docker run -v ${{ github.workspace }}:/workspace \
      mensfeld/llm-docs-builder generate --config llm-docs-builder.yml
```

**GitLab CI:**
```yaml
generate-llms:
  image: mensfeld/llm-docs-builder:latest
  script:
    - llm-docs-builder generate --docs ./docs
```

**Jenkins:**
```groovy
stage('Generate LLMS.txt') {
    steps {
        sh 'docker run -v ${WORKSPACE}:/workspace mensfeld/llm-docs-builder generate --docs ./docs'
    }
}
```

### Using Specific Versions

```bash
# Use specific version
docker run mensfeld/llm-docs-builder:0.3.0 version

# Use major version (gets latest patch)
docker run mensfeld/llm-docs-builder:0 version

# Use GitHub Container Registry
docker run ghcr.io/mensfeld/llm-docs-builder:latest version
```

### Volume Mount Tips

**Mount specific directory:**
```bash
# Mount only the docs folder
docker run -v $(pwd)/docs:/workspace/docs mensfeld/llm-docs-builder generate --docs ./docs
```

**Windows (PowerShell):**
```powershell
docker run -v ${PWD}:/workspace mensfeld/llm-docs-builder generate --docs ./docs
```

**Windows (Command Prompt):**
```cmd
docker run -v %cd%:/workspace mensfeld/llm-docs-builder generate --docs ./docs
```

## CLI Reference

### Commands

```bash
llm-docs-builder generate [options]       # Generate llms.txt from documentation (default)
llm-docs-builder transform [options]      # Transform a markdown file to be AI-friendly
llm-docs-builder bulk-transform [options] # Transform all markdown files in directory
llm-docs-builder compare [options]        # Compare content sizes to measure context savings
llm-docs-builder parse [options]          # Parse existing llms.txt file
llm-docs-builder validate [options]       # Validate llms.txt file
llm-docs-builder version                  # Show version
```

### Options

```bash
-c, --config PATH        Configuration file path (default: llm-docs-builder.yml)
-d, --docs PATH          Path to documentation directory or file
-o, --output PATH        Output file path
-u, --url URL            URL to fetch for comparison
-f, --file PATH          Local markdown file for comparison
-v, --verbose            Verbose output
-h, --help               Show help message
```

*For advanced options like base_url, title, description, suffix, excludes, and convert_urls, use a config file.*

## Configuration File

The recommended way to use llm-docs-builder is with a `llm-docs-builder.yml` config file. This allows you to:

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
suffix: .llm         # Suffix for transformed files (use "" for in-place)
verbose: false       # Enable verbose output

# Exclusion patterns (optional)
excludes:
  - "**/private/**"
  - "**/drafts/**"
```

The config file will be automatically found if named:
- `llm-docs-builder.yml`
- `llm-docs-builder.yaml`
- `.llm-docs-builder.yml`

### Configuration Options Reference

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `docs` | String | `./docs` | Directory containing markdown files to process |
| `base_url` | String | - | Base URL for expanding relative links (e.g., `https://myproject.io`) |
| `title` | String | Auto-detected | Project title for llms.txt generation |
| `description` | String | Auto-detected | Project description for llms.txt generation |
| `output` | String | `llms.txt` | Output filename for generated llms.txt |
| `convert_urls` | Boolean | `false` | Convert HTML URLs to markdown format (`.html` → `.md`) |
| `suffix` | String | `.llm` | Suffix added to transformed files. Use `""` for in-place transformation |
| `excludes` | Array | `[]` | Glob patterns for files/directories to exclude from processing |
| `verbose` | Boolean | `false` | Enable detailed output during processing |

## Bulk Transformation

The `bulk-transform` command processes all markdown files in a directory recursively, creating
AI-friendly versions. By default, it creates new files with a `.llm.md` suffix, but you can also transform files in-place for build pipelines.

### Key Features

- **Recursive processing** - Finds and transforms all `.md` files in nested directories
- **Preserves structure** - Maintains your existing directory layout
- **Exclusion patterns** - Skip files/directories using glob patterns
- **Custom suffixes** - Choose how transformed files are named, or transform in-place
- **LLM optimizations** - Expands relative links, converts HTML URLs, etc.

### Default Behavior: Creating Separate Files

By default, `bulk-transform` creates new `.llm.md` files alongside your originals:

```yaml
# llm-docs-builder.yml
docs: ./docs
base_url: https://myproject.io
suffix: .llm         # Creates .llm.md files (default if omitted)
convert_urls: true
```

```bash
llm-docs-builder bulk-transform --config llm-docs-builder.yml
```

**Result:**
```
docs/
├── README.md
├── README.llm.md          ← AI-friendly version
├── setup.md
└── setup.llm.md           ← AI-friendly version
```

This preserves your original files and creates LLM-optimized versions separately.

### In-Place Transformation

For build pipelines where you want to transform documentation directly without maintaining separate copies, use `suffix: ""`:

```yaml
# llm-docs-builder.yml
docs: ./docs
base_url: https://myproject.io
convert_urls: true
suffix: ""  # Transform in-place, no separate files
excludes:
  - "**/private/**"
  - "**/drafts/**"
```

```bash
llm-docs-builder bulk-transform --config llm-docs-builder.yml
```

**Before transformation** (`docs/setup.md`):
```markdown
See the [configuration guide](../config.md) for details.
Visit our [API docs](https://myproject.io/api/).
```

**After transformation** (`docs/setup.md` - same file, overwritten):
```markdown
See the [configuration guide](https://myproject.io/docs/config.md) for details.
Visit our [API docs](https://myproject.io/api.md).
```

This is perfect for:
- **Build pipelines** - Transform docs as part of your deployment process
- **Static site generators** - Process markdown before building HTML
- **CI/CD workflows** - Automated documentation transformation

### Real-World Example: Karafka Framework

The [Karafka framework](https://github.com/karafka/website) uses in-place transformation in its documentation build process. Previously, it had 140+ lines of custom Ruby code for link expansion and URL conversion. Now it uses:

```yaml
# llm-docs-builder.yml
docs: ./online/docs
base_url: https://karafka.io/docs
convert_urls: true
suffix: ""
excludes:
  - "**/Enterprise-License-Setup/**"
```

```bash
# In their build script (sync.rb)
system!("llm-docs-builder bulk-transform --config llm-docs-builder.yml")
```

This configuration:
- Processes all markdown files recursively in `./online/docs`
- Expands relative links to absolute URLs using the base_url
- Converts HTML URLs to markdown format (`.html` → `.md`)
- Transforms files in-place (no separate `.llm.md` files)
- Excludes password-protected enterprise documentation
- Runs as part of an automated daily deployment via GitHub Actions

**Result**: Over 140 lines of custom code replaced with a 6-line configuration file.

### Usage Examples

```bash
# Transform all files with default settings (creates .llm.md files)
llm-docs-builder bulk-transform --docs ./wiki

# Transform in-place using config file
llm-docs-builder bulk-transform --config karafka-config.yml

# Verbose output to see processing details
llm-docs-builder bulk-transform --config llm-docs-builder.yml --verbose
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

### Example Output (Default Suffix)

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

### Example Output (In-Place Transformation)

With `suffix: ""`, the original files are overwritten:
```
wiki/
├── Home.md              ← Transformed in-place
├── getting-started.md   ← Transformed in-place
├── api/
│   ├── consumers.md     ← Transformed in-place
│   └── producers.md     ← Transformed in-place
└── private/
    └── internal.md      ← Excluded from transformation
```

## Serving LLM-Friendly Documentation

After using `bulk-transform` to create `.llm.md` versions of your documentation, you can configure your web server to automatically serve these LLM-optimized versions to AI bots while showing the original versions to human visitors.

> **Note:** This section applies when using the default `suffix: .llm` behavior. If you're using `suffix: ""` for in-place transformation, the markdown files are already LLM-optimized and can be served directly.

### How It Works

The strategy is simple:

1. **Detect AI bots** by their User-Agent strings
2. **Serve `.llm.md` files** to detected AI bots
3. **Serve original `.md` files** to human visitors
4. **Automatic selection** - no manual switching needed

### Apache Configuration

Add this to your `.htaccess` file:

```apache
# Detect LLM bots by User-Agent
SetEnvIf User-Agent "(?i)(openai|anthropic|claude|gpt|chatgpt|bard|gemini|copilot)" IS_LLM_BOT
SetEnvIf User-Agent "(?i)(perplexity|character\.ai|you\.com|poe\.com|huggingface|replicate)" IS_LLM_BOT
SetEnvIf User-Agent "(?i)(langchain|llamaindex|semantic|embedding|vector|rag)" IS_LLM_BOT
SetEnvIf User-Agent "(?i)(ollama|mistral|cohere|together|fireworks|groq)" IS_LLM_BOT

# Serve .md files as text/plain
<FilesMatch "\.md$">
  Header set Content-Type "text/plain; charset=utf-8"
  ForceType text/plain
</FilesMatch>

# Enable rewrite engine
RewriteEngine On

# For LLM bots: rewrite requests to serve .llm.md versions
RewriteCond %{ENV:IS_LLM_BOT} !^$
RewriteCond %{REQUEST_URI} ^/docs/.*\.md$ [NC]
RewriteCond %{REQUEST_URI} !\.llm\.md$ [NC]
RewriteCond %{DOCUMENT_ROOT}%{REQUEST_URI} -f
RewriteRule ^(.*)\.md$ $1.llm.md [L]

# For LLM bots: handle clean URLs by appending .llm.md
RewriteCond %{ENV:IS_LLM_BOT} !^$
RewriteCond %{REQUEST_URI} ^/docs/ [NC]
RewriteCond %{REQUEST_URI} !\.md$ [NC]
RewriteCond %{DOCUMENT_ROOT}%{REQUEST_URI}.llm.md -f
RewriteRule ^(.*)$ $1.llm.md [L]

# For regular users: serve original .md files or clean URLs as usual
# (add your normal URL handling rules here)
```

### Nginx Configuration

Add this to your nginx server block:

```nginx
# Map to detect LLM bots
map $http_user_agent $is_llm_bot {
    default 0;
    "~*(?i)(openai|anthropic|claude|gpt|chatgpt|bard|gemini|copilot)" 1;
    "~*(?i)(perplexity|character\.ai|you\.com|poe\.com|huggingface|replicate)" 1;
    "~*(?i)(langchain|llamaindex|semantic|embedding|vector|rag)" 1;
    "~*(?i)(ollama|mistral|cohere|together|fireworks|groq)" 1;
}

server {
    # ... your server configuration ...

    # Serve .md files as text/plain
    location ~ \.md$ {
        default_type text/plain;
        charset utf-8;
    }

    # For LLM bots requesting .md files, serve .llm.md version
    location ~ ^/docs/(.*)\.md$ {
        if ($is_llm_bot) {
            rewrite ^(.*)\.md$ $1.llm.md last;
        }
        try_files $uri $uri/ =404;
    }

    # For LLM bots requesting clean URLs, serve .llm.md version
    location ~ ^/docs/ {
        if ($is_llm_bot) {
            try_files $uri.llm.md $uri $uri/ =404;
        }
        try_files $uri $uri.md $uri/ =404;
    }
}
```

### Cloudflare Workers

For serverless deployments, use Cloudflare Workers:

```javascript
export default {
  async fetch(request) {
    const url = new URL(request.url);
    const userAgent = request.headers.get('user-agent') || '';

    // Detect LLM bots
    const llmBotPatterns = [
      /openai|anthropic|claude|gpt|chatgpt|bard|gemini|copilot/i,
      /perplexity|character\.ai|you\.com|poe\.com|huggingface|replicate/i,
      /langchain|llamaindex|semantic|embedding|vector|rag/i,
      /ollama|mistral|cohere|together|fireworks|groq/i
    ];

    const isLLMBot = llmBotPatterns.some(pattern => pattern.test(userAgent));

    // If LLM bot and requesting docs
    if (isLLMBot && url.pathname.startsWith('/docs/')) {
      // Try to serve .llm.md version
      const llmPath = url.pathname.replace(/\.md$/, '.llm.md');
      if (!url.pathname.endsWith('.llm.md')) {
        url.pathname = llmPath;
      }
    }

    return fetch(url);
  }
}
```

### Custom Suffix

If you used a different suffix with the `bulk-transform` command (e.g., `suffix: .ai`), update your web server rules accordingly.

**Apache:**
```apache
RewriteRule ^(.*)\.md$ $1.ai.md [L]
```

**Nginx:**
```nginx
rewrite ^(.*)\.md$ $1.ai.md last;
```

**Cloudflare Workers:**
```javascript
const llmPath = url.pathname.replace(/\.md$/, '.ai.md');
```

## Ruby API

### Basic Usage

```ruby
require 'llm_docs_builder'

# Option 1: Using config file (recommended)
content = LlmDocsBuilder.generate_from_docs(config_file: 'llm-docs-builder.yml')

# Option 2: Direct options (overrides config)
content = LlmDocsBuilder.generate_from_docs('./docs',
  base_url: 'https://myproject.io',
  title: 'My Project',
  description: 'A great project'
)

# Option 3: Mix config file with overrides
content = LlmDocsBuilder.generate_from_docs('./docs',
  config_file: 'my-config.yml',
  title: 'Override Title'  # This overrides config file title
)

# Transform markdown with config
transformed = LlmDocsBuilder.transform_markdown('README.md',
  config_file: 'llm-docs-builder.yml'
)

# Transform with direct options
transformed = LlmDocsBuilder.transform_markdown('README.md',
  base_url: 'https://myproject.io',
  convert_urls: true
)

# Bulk transform all files in directory (creates .llm.md files)
transformed_files = LlmDocsBuilder.bulk_transform('./wiki',
  base_url: 'https://karafka.io',
  suffix: '.llm',
  excludes: ['**/private/**', '**/draft-*.md']
)
puts "Transformed #{transformed_files.size} files"

# Bulk transform in-place (overwrites original files)
transformed_files = LlmDocsBuilder.bulk_transform('./wiki',
  base_url: 'https://karafka.io',
  suffix: '',  # Empty string for in-place transformation
  convert_urls: true,
  excludes: ['**/private/**']
)

# Bulk transform with config file
transformed_files = LlmDocsBuilder.bulk_transform('./wiki',
  config_file: 'karafka-config.yml'
)

# Parse and validate (unchanged)
parsed = LlmDocsBuilder.parse('llms.txt')
puts parsed.title
puts parsed.description

valid = LlmDocsBuilder.validate(content)
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

## Comparing Context Window Savings

The `compare` command helps you measure how much context window space is saved by serving LLM-optimized versions of your documentation. It compares content sizes between human and AI versions to quantify the reduction.

### Use Cases

**1. Compare remote versions with different User-Agents**

Check how much smaller your server sends to AI bots compared to regular browsers:

```bash
llm-docs-builder compare --url https://karafka.io/docs/Getting-Started.html
```

Output:
```
============================================================
Context Window Comparison
============================================================

Human version:  45.2 KB
  Source: https://karafka.io/docs/Getting-Started.html (User-Agent: human)

AI version:     12.8 KB
  Source: https://karafka.io/docs/Getting-Started.html (User-Agent: AI)

------------------------------------------------------------
Reduction:      32.4 KB (72%)
Factor:         3.5x smaller
============================================================
```

**2. Compare remote with local markdown**

Test your local markdown files before deploying:

```bash
llm-docs-builder compare --url https://example.com/docs/page.html --file docs/page.md
```

This fetches the current live version and compares it with your local markdown to see the potential savings.

**3. Verbose mode for debugging**

```bash
llm-docs-builder compare --url https://example.com/docs --verbose
```

Shows fetching progress and detailed information about what's being compared.

### How It Works

The compare command:
1. **For remote-only comparison**: Fetches the URL twice with different User-Agents (simulating human browser vs AI bot)
2. **For local comparison**: Fetches the URL once (human User-Agent) and reads your local markdown file
3. **Calculates metrics**: Computes reduction percentage and compression factor
4. **Displays results**: Shows size comparison in human-readable format (bytes, KB, MB)

This helps you:
- **Validate optimizations**: Confirm your LLM-optimized versions are actually smaller
- **Measure impact**: Quantify context window savings for your users
- **Test before deploy**: Check local changes against live versions
- **Monitor effectiveness**: Track savings across different pages

## Example Output

Given a `docs/` directory with:
- `README.md`
- `getting-started.md`
- `api-reference.md`

Running `llm-docs-builder generate --docs ./docs --base-url https://myproject.io` creates:

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

Bug reports and pull requests are welcome on GitHub at https://github.com/mensfeld/llm-docs-builder.

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
