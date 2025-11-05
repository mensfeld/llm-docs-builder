# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**llm-docs-builder** is a Ruby gem that transforms markdown documentation to be AI-friendly and generates `llms.txt` files. It reduces token consumption by 67-95% by removing unnecessary content (navigation, badges, comments, etc.) and optimizes documents for LLM context windows and RAG systems.

**Real-world impact:** Karafka documentation saw 83% average token reduction after transformation.

## Common Development Commands

### Setup & Dependencies
```bash
bundle install                    # Install gem dependencies
```

### Testing & Linting
```bash
bundle exec rake                  # Default task: run all tests + rubocop
bundle exec rake spec             # Run only RSpec tests
bundle exec rspec                 # Execute full test suite
bin/rspecs                        # Execute tests with documentation formatter
bundle exec rubocop               # Enforce Ruby style guide
bundle exec rubocop -a            # Auto-correct linting issues
SIMPLECOV=false bundle exec rspec # Skip coverage for faster runs
```

### CLI Usage
```bash
# Compare token savings between human and AI versions
bin/llm-docs-builder compare --url https://yoursite.com/docs/page.html

# Transform a single markdown file
bin/llm-docs-builder transform --docs README.md

# Bulk transform with config
bin/llm-docs-builder bulk-transform --config llm-docs-builder.yml

# Generate llms.txt from documentation
bin/llm-docs-builder generate --docs ./docs

# Parse/validate llms.txt
bin/llm-docs-builder parse --file llms.txt
bin/llm-docs-builder validate --file llms.txt
```

### Docker Workflow
```bash
# Build Docker image
docker build -t llm-docs-builder .

# Run via Docker (recommended)
docker run -v $(pwd):/workspace mensfeld/llm-docs-builder \
  bulk-transform --config llm-docs-builder.yml
```

## Code Architecture

### Entry Points

**CLI Executable:** `bin/llm-docs-builder`
- Bootstraps the application
- Requires `lib/llm_docs_builder` (Zeitwerk autoload)
- Delegates to `LlmDocsBuilder::CLI.run`

**Main Module:** `lib/llm_docs_builder.rb`
- Uses Zeitwerk autoloading for dependency management
- Exposes 5 public API methods:
  - `generate_from_docs()` - Generate llms.txt from documentation
  - `transform_markdown()` - Transform single markdown file
  - `bulk_transform()` - Transform multiple files with exclusions
  - `parse()` - Parse existing llms.txt
  - `validate()` - Validate llms.txt spec compliance

### Core Modules

**CLI Layer:** `lib/llm_docs_builder/cli.rb`
- Implements 6 commands: compare, transform, bulk-transform, generate, parse, validate
- Handles argument parsing and option delegation
- Integrates with Config for settings management

**Transformation Pipeline:** `lib/llm_docs_builder/markdown_transformer.rb`
- Orchestrates 5 specialized transformers (see below)
- Processes markdown content through configurable cleanup/enhancement stages
- Supports both single-file and bulk transformations

**Five Transformer Modules** (`lib/llm_docs_builder/transformers/`):
1. **ContentCleanupTransformer** - Removes badges, comments, frontmatter, images, code examples, blockquotes
2. **EnhancementTransformer** - Generates TOC, adds custom instructions, removes duplicates, stopwords
3. **HeadingTransformer** - Normalizes headings with hierarchical context (e.g., "Configuration / Consumer Settings / auto_offset_reset")
4. **LinkTransformer** - Simplifies verbose link text, converts HTML URLs to Markdown
5. **WhitespaceTransformer** - Normalizes whitespace, reduces excessive blank lines

**Supporting Modules:**
- `generator.rb` - Creates llms.txt with metadata (tokens, timestamps, priority labels)
- `bulk_transformer.rb` - Batch processing with exclusion patterns, progress tracking
- `comparator.rb` - Measures token savings between human/AI versions using TokenEstimator
- `config.rb` - YAML configuration loader with auto-discovery
- `html_to_markdown_converter.rb` - HTML→Markdown conversion using Nokogiri
- `token_estimator.rb` - Accurate token counting for cost analysis

### Configuration System

**Configuration File:** `llm-docs-builder.yml` (see `llm-docs-builder.yml.example`)

Key sections:
- `docs` - Documentation path
- `base_url` - Base URL for expanding relative links
- `title`/`description` - Project metadata
- `output` - Output file path
- `suffix` - File suffix for bulk transforms (e.g., `.llm`)
- `excludes` - Exclusion patterns
- **Transform options:** `convert_urls`, `remove_comments`, `remove_badges`, `remove_frontmatter`, `remove_images`, `remove_code_examples`, `remove_blockquotes`, `remove_duplicates`, `remove_stopwords`, `generate_toc`, `simplify_links`, `normalize_whitespace`
- **RAG enhancements:** `normalize_headings`, `heading_separator`, `include_metadata`, `include_tokens`, `include_timestamps`, `include_priority`

### Test Structure

**Testing Framework:** RSpec with SimpleCov coverage
- 16+ unit test files in `spec/`
- Integration tests in `spec/integrations/` for CLI workflows
- Transformer-specific tests in `spec/transformers/`
- Test coverage reports in `coverage/`
- `.rspec` enables documentation format and color output

**Key Test Files:**
- `spec/*_spec.rb` - Unit tests for each module
- `spec/integrations/cli_spec.rb` - CLI command integration tests
- `spec/transformers/*_spec.rb` - Individual transformer tests
- `spec/fixtures/` - Test data and fixtures

### Dependencies

**Runtime:** Only 2 gems
- `nokogiri ~> 1.17` - HTML/XML parsing for HTML→Markdown conversion
- `zeitwerk ~> 2.6` - Modern autoloader for `lib/llm_docs_builder/`

**Development:** RSpec, RuboCop, SimpleCov, Rake, Bundler

## Development Guidelines (from AGENTS.md)

### Coding Standards
- **Ruby Version:** 3.2+
- **Indentation:** Two spaces
- **Strings:** Prefer single-quoted
- **Line Length:** ≤120 characters (configurable via RuboCop)
- **Headers:** Use `# frozen_string_literal: true`
- **Method Naming:** Predicates end with `?`
- **Modules:** Descriptive names (e.g., `LlmDocsBuilder::Generator`)

### Project Structure
- Core code: `lib/llm_docs_builder/`
- Single-responsibility modules (Generator, Validator, CLI, etc.)
- Executables: `bin/llm-docs-builder` (CLI), `bin/rspecs` (test runner)
- Specs mirror library files under `spec/`
- Static assets in `misc/`
- Configuration template: `llm-docs-builder.yml.example`

### Testing Approach
- RSpec is the sole testing framework
- Files: `*_spec.rb`
- Integration tests capture CLI behaviors in `spec/integrations/`
- SimpleCov enabled (line and branch coverage)
- Export `SIMPLECOV=false` for faster local runs
- Example statuses persisted in `spec/examples.txt`

### Commit & PR Process
- Keep subjects short, present-tense, focused
- Group related changes for readable git log
- PRs should describe motivation, summarize impact, link issues
- Include CLI output/screenshots when touching docs generation
- Ensure CI passes (`bundle exec rake`) before review

## CI/CD Pipeline

**GitHub Actions** (3 workflows):
1. **ci.yml** - Tests on Ruby 3.2, 3.3, 3.4 with coverage
2. **docker.yml** - Docker builds and publishes to Docker Hub
3. **push.yml** - Post-merge notifications

**Docker Distribution:**
- Multi-stage build (ruby:3.4-alpine → ~50MB runtime)
- Published as `mensfeld/llm-docs-builder:latest`

## Key Configuration Examples

**Bulk Transform with Exclusions:**
```yaml
docs: ./docs
suffix: .llm
excludes:
  - "**/private/**"
  - "**/draft-*.md"
  - "**/.*"
```

**RAG Enhancement:**
```yaml
normalize_headings: true          # Hierarchical context
heading_separator: " / "
include_metadata: true            # Enable enhanced metadata
include_tokens: true              # Token counts
include_timestamps: true          # Last modified dates
include_priority: true            # Priority labels (high/medium/low)
```

**Aggressive Compression:**
```yaml
remove_frontmatter: true
remove_comments: true
remove_badges: true
remove_images: true
remove_code_examples: true
remove_blockquotes: true
remove_duplicates: true
remove_stopwords: true
```

## Important Files

- `lib/llm_docs_builder.rb` - Main entry point, Zeitwerk setup
- `lib/llm_docs_builder/cli.rb` - CLI command implementation
- `lib/llm_docs_builder/markdown_transformer.rb` - Transformation pipeline
- `lib/llm_docs_builder/transformers/*.rb` - 5 specialized transformers
- `lib/llm_docs_builder/generator.rb` - llms.txt generation
- `lib/llm_docs_builder/bulk_transformer.rb` - Batch processing
- `lib/llm_docs_builder/config.rb` - YAML configuration loader
- `llm-docs-builder.yml.example` - Configuration template
- `Rakefile` - Default task: `spec` + `rubocop`
- `AGENTS.md` - Developer guidelines
- `README.md` - Comprehensive usage documentation with examples

## Ruby LSP Support

The project includes `.ruby-lsp/` configuration for Ruby Language Server Protocol support, enabling IDE features like code navigation, completion, and diagnostics in compatible editors.
