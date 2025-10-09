# CLAUDE.md

llm-docs-builder is a Ruby gem that generates [llms.txt](https://llmstxt.org/) files from existing markdown documentation and transforms markdown files to be AI-friendly. It provides both a CLI tool and Ruby API.

## Project Overview

llm-docs-builder is a Ruby gem that generates [llms.txt](https://llmstxt.org/) files from existing markdown documentation and transforms markdown files to be AI-friendly. It provides both a CLI tool and Ruby API.

**Key functionality:**
- Generates llms.txt files from documentation directories by scanning markdown files, extracting metadata, and organizing by priority
- Transforms individual markdown files by expanding relative links to absolute URLs
- Bulk transforms entire documentation trees with customizable suffixes and exclusion patterns
- Supports both config file and direct options for all operations

## Development Commands

### Testing
```bash
# Run all tests
./bin/rspecs

# Run specific test file
bundle exec rspec spec/llm_docs_builder_spec.rb

# Run specific test line
bundle exec rspec spec/llm_docs_builder_spec.rb:42
```

### Code Quality
```bash
# Run RuboCop linter
bundle exec rubocop

# Auto-fix RuboCop violations
bundle exec rubocop -a

# Run all checks (tests + linting)
bundle exec rake
```

### CLI Testing
```bash
# Test CLI locally
bundle exec bin/llm-docs-builder generate --docs ./docs
bundle exec bin/llm-docs-builder transform --docs README.md
bundle exec bin/llm-docs-builder bulk-transform --docs ./docs

# Test compare command (requires network)
bundle exec bin/llm-docs-builder compare --url https://karafka.io/docs/Getting-Started.html
bundle exec bin/llm-docs-builder compare --url https://example.com/page.html --file docs/local.md
```

### Building and Installing
```bash
# Build gem locally
bundle exec rake build

# Install locally built gem
gem install pkg/llm-docs-builder-*.gem

# Release (maintainers only)
bundle exec rake release
```

## Architecture

### Core Components

**LlmDocsBuilder Module** (`lib/llm_docs_builder.rb`)
- Main API entry point with class methods for all operations
- Uses Zeitwerk for autoloading
- Delegates to specialized classes for generation, transformation, and validation
- All methods support both config file and direct options via `Config#merge_with_options`

**Generator** (`lib/llm_docs_builder/generator.rb`)
- Scans documentation directories recursively using `Find.find`
- Extracts title from first H1 header, description from first paragraph
- Prioritizes files: README (1), getting started (2), guides (3), tutorials (4), API (5), reference (6), others (7)
- Builds formatted llms.txt with links and descriptions

**MarkdownTransformer** (`lib/llm_docs_builder/markdown_transformer.rb`)
- Transforms individual markdown files using regex patterns
- `expand_relative_links`: Converts relative links to absolute URLs using base_url
- `convert_html_urls`: Changes .html/.htm URLs to .md format
- Leaves absolute URLs and anchor links unchanged

**BulkTransformer** (`lib/llm_docs_builder/bulk_transformer.rb`)
- Recursively processes all markdown files in a directory
- Uses `MarkdownTransformer` for each file
- Generates output paths with configurable suffix (default: `.llm`)
- Empty suffix (`""`) enables in-place transformation
- Supports glob-based exclusion patterns via `File.fnmatch`

**Comparator** (`lib/llm_docs_builder/comparator.rb`)
- Measures context window savings by comparing content sizes
- Fetches URLs with different User-Agents (human browser vs AI bot)
- Can compare remote URL with local markdown file
- Uses Net::HTTP for fetching with redirect support
- Calculates reduction percentage, bytes saved, and compression factor

**Config** (`lib/llm_docs_builder/config.rb`)
- Loads YAML config from file or auto-finds `llms-txt.yml`
- Merges config file options with programmatic options (programmatic takes precedence)
- Handles defaults: `suffix: '.llm'`, `output: 'llms.txt'`, `excludes: []`

**CLI** (`lib/llm_docs_builder/cli.rb`)
- Parses commands: generate, transform, bulk-transform, compare, parse, validate, version
- Uses OptionParser for flag parsing
- Loads config and merges with CLI options before delegating to main module
- Handles errors gracefully with user-friendly messages
- Compare command displays formatted output with human-readable byte sizes (bytes/KB/MB)

### Configuration Precedence

Options are resolved in this order (highest to lowest priority):
1. Direct method arguments (e.g., `LlmDocsBuilder.generate_from_docs('./docs', title: 'Override')`)
2. CLI flags (e.g., `--docs ./docs`)
3. Config file values (e.g., `llms-txt.yml`)
4. Defaults (e.g., `suffix: '.llm'`, `output: 'llms.txt'`)

### File Priority System

When generating llms.txt, files are automatically ordered by importance:
- Priority 1: README files (always listed first)
- Priority 2: Getting started guides
- Priority 3: General guides
- Priority 4: Tutorials
- Priority 5: API documentation
- Priority 6: Reference documentation
- Priority 7: All other files

### Link Transformation Logic

**Relative Link Expansion** (when `base_url` provided):
- Converts `[text](./path.md)` → `[text](https://base.url/path.md)`
- Converts `[text](../other.md)` → `[text](https://base.url/other.md)`
- Skips URLs starting with `http://`, `https://`, `//`, or `#`

**URL Conversion** (when `convert_urls: true`):
- Changes `https://example.com/page.html` → `https://example.com/page.md`
- Changes `https://example.com/doc.htm` → `https://example.com/doc.md`

### In-Place vs Separate Files

**Separate Files** (`suffix: '.llm'` - default):
- Creates new files: `README.md` → `README.llm.md`
- Preserves originals for human-readable documentation
- Useful for dual-serving human and AI versions

**In-Place** (`suffix: ""`):
- Overwrites originals: `README.md` → `README.md` (transformed)
- Used in build pipelines (e.g., Karafka framework)
- Transforms documentation before deployment

## Testing Strategy

- RSpec for all tests with SimpleCov coverage tracking
- Unit tests for each component in isolation
- Integration tests in `spec/integrations/` for end-to-end workflows
- Example outputs saved in `spec/examples.txt` for persistence
- CI tests against Ruby 3.2, 3.3, 3.4 via GitHub Actions

## Dependencies

- **zeitwerk**: Autoloading and code organization
- **optparse**: Built-in Ruby CLI parsing (no external CLI framework)
- **rspec**: Testing framework
- **rubocop**: Code linting and style enforcement
- **simplecov**: Test coverage reporting

## Code Style

- Ruby 3.2+ syntax and features required
- Frozen string literals in all files
- Explicit module nesting (no `class Foo::Bar`)
- Comprehensive YARD documentation for public APIs
- Private methods clearly marked and documented
- RuboCop enforces consistent style
