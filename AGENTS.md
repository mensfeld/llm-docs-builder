# Repository Guidelines

## Project Overview

llm-docs-builder is a Ruby gem that optimizes documentation for Large Language Models (LLMs) and RAG systems. It transforms markdown documentation to reduce token consumption by 67-95% while maintaining content quality and improving AI comprehension.

**Key Capabilities:**
- Generate llms.txt files from documentation directories with automatic file prioritization
- Transform individual markdown files by expanding relative links to absolute URLs
- Bulk transform entire documentation trees with customizable exclusion patterns
- Compare content sizes to measure context window savings
- Validate llms.txt content for specification compliance
- Serve LLM-optimized documentation via built-in server

## Technology Stack

- **Language**: Ruby 3.2+ (supports 3.2, 3.3, 3.4)
- **Dependencies**: Nokogiri (~> 1.17) for HTML/XML parsing, Zeitwerk (~> 2.6) for autoloading
- **Development Tools**: RSpec for testing, RuboCop for linting, SimpleCov for coverage
- **Runtime**: Bundler for dependency management, Zeitwerk for code loading
- **Containerization**: Multi-stage Docker builds with Alpine Linux (~50MB final image)

## Project Structure & Module Organization

```
lib/llm_docs_builder/           # Core gem modules
├── cli.rb                      # Command-line interface
├── generator.rb                # llms.txt generation logic
├── markdown_transformer.rb     # Single file transformation
├── bulk_transformer.rb         # Bulk file transformation
├── parser.rb                   # llms.txt parsing
├── validator.rb                # Content validation
├── config.rb                   # Configuration management
├── transformers/               # Modular transformation pipeline
│   ├── base_transformer.rb     # Abstract transformer class
│   ├── link_transformer.rb     # Link normalization
│   ├── content_cleanup_transformer.rb  # Content optimization
│   ├── enhancement_transformer.rb      # AI-friendly enhancements
│   ├── whitespace_transformer.rb       # Whitespace normalization
│   └── heading_transformer.rb          # Heading structure optimization
├── helpers.rb                  # Utility functions
├── errors.rb                   # Custom exception classes
├── html_detector.rb            # HTML content detection
├── url_fetcher.rb              # Remote content fetching
├── html_to_markdown_converter.rb       # HTML to Markdown conversion
├── text_compressor.rb          # Text compression utilities
└── output_formatter.rb         # Output formatting

bin/                            # Executables
├── llm-docs-builder            # Main CLI entry point
└── rspecs                      # Test runner script

spec/                           # Test suite
├── *_spec.rb                   # Unit tests mirroring lib structure
└── integrations/               # Integration tests for CLI behaviors
```

## Build, Test, and Development Commands

### Essential Commands
```bash
# Install dependencies
bundle install

# Run all tests and linting (default task)
bundle exec rake

# Run tests only
bundle exec rspec
# or use the custom test runner
bin/rspecs

# Run linting only
bundle exec rubocop

# Auto-fix linting issues
bundle exec rubocop -a

# Build the gem
gem build llm-docs-builder.gemspec

# Install locally for testing
gem install ./llm-docs-builder-*.gem
```

### CLI Testing
```bash
# Smoke test the CLI against a local file
bin/llm-docs-builder transform --docs README.md

# Generate llms.txt from docs directory
bin/llm-docs-builder generate --docs ./docs --output llms.txt

# Compare token usage between versions
bin/llm-docs-builder compare --url https://example.com/docs

# Validate llms.txt file
bin/llm-docs-builder validate --file llms.txt
```

### Docker Usage
```bash
# Build Docker image
docker build -t llm-docs-builder .

# Run without Ruby installation
docker run --rm -v $(pwd):/workspace llm-docs-builder transform --docs README.md

# Compare documentation pages
docker run --rm llm-docs-builder compare --url https://yoursite.com/docs/page.html
```

## Code Style Guidelines

### Ruby Style Requirements
- **Target Ruby Version**: 3.2+ with modern syntax features
- **Indentation**: 2 spaces, no tabs
- **Line Length**: Maximum 120 characters (enforced by RuboCop)
- **String Quotes**: Prefer single quotes, double quotes for interpolation
- **Frozen Strings**: All files must include `# frozen_string_literal: true`
- **Method Length**: Maximum 35 lines (exceptions for CLI methods)
- **Class Length**: Maximum 200 lines (exceptions for CLI class)

### Naming Conventions
- **Modules/Classes**: PascalCase with descriptive names (e.g., `LlmDocsBuilder::Generator`)
- **Methods**: snake_case with predicate methods ending in `?` for booleans
- **Files**: snake_case matching the class/module name
- **Constants**: UPPER_CASE with underscores

### Code Organization
- Single-responsibility modules with clear separation of concerns
- Transformer pipeline architecture for extensibility
- Configuration-driven behavior with sensible defaults
- Comprehensive error handling with custom exception classes
- Extensive documentation with YARD comments for public APIs

## Testing Guidelines

### Test Structure
- **Framework**: RSpec exclusively (no Minitest or other frameworks)
- **File Naming**: `*_spec.rb` files mirroring the lib structure
- **Test Organization**: Unit tests in `spec/`, integration tests in `spec/integrations/`
- **Coverage**: SimpleCov enabled by default for line and branch coverage

### Test Execution
```bash
# Run all tests with documentation format
bundle exec rspec spec/ --format documentation

# Run specific test file
bundle exec rspec spec/generator_spec.rb

# Run with coverage disabled (for quick local runs)
SIMPLECOV=false bundle exec rspec

# Persist example statuses
bundle exec rspec --format documentation --order defined
```

### Test Best Practices
- Align `describe` blocks with constant paths being tested
- Use meaningful test descriptions that explain the behavior
- Integration tests should capture CLI behaviors and end-to-end workflows
- Mock external dependencies appropriately
- Test both success and error paths

## Configuration Management

### Configuration File Format
YAML configuration files support the following options:

```yaml
# Path to documentation directory or file
docs: ./docs

# Base URL for expanding relative links (optional)
base_url: https://myproject.io

# Project information (auto-detected if not provided)
title: My Awesome Project
description: A Ruby library for amazing things

# Output configuration
output: llms.txt

# Transformation options
convert_urls: true    # Convert .html links to .md
verbose: false        # Verbose output

# Bulk transformation options
suffix: .llm          # Suffix for transformed files
excludes:             # Glob patterns for files to exclude
  - "**/private/**"
  - "**/draft-*.md"
  - "/.*"             # Hidden files (auto-excluded by default)

# Include hidden directories (default: false)
include_hidden: false

# Optional body content for llms.txt
body: |
  Additional content between description and sections
```

### Configuration Resolution
- Command-line options override configuration file settings
- Configuration file auto-discovery looks for `llms-docs-builder.yml`
- Environment-specific configurations supported via file paths
- Sensible defaults for all configuration options

## Deployment & Distribution

### Gem Distribution
- Published to RubyGems.org with MFA requirement
- Automated versioning via `lib/llm_docs_builder/version.rb`
- Git-based file selection using `git ls-files`
- MIT license with clear attribution

### Docker Distribution
- Multi-stage builds for minimal runtime images
- Automated builds via GitHub Actions on version tags
- Published to Docker Hub as `mensfeld/llm-docs-builder`
- Alpine Linux base for security and size optimization

### CI/CD Pipeline
- GitHub Actions workflows for continuous integration
- Matrix testing across Ruby 3.2, 3.3, 3.4
- Coverage reporting and artifact collection
- Automated gem building and Docker image publishing

## Security Considerations

### Input Validation
- All file paths validated before processing
- URL fetching with proper error handling and timeouts
- HTML content sanitization before transformation
- Configuration file validation against expected schema

### Safe Defaults
- Hidden directories excluded by default to prevent information leakage
- Safe file pattern matching to prevent directory traversal
- Conservative HTML parsing to prevent XSS in output
- No execution of user-provided code or scripts

### Dependencies
- Minimal dependency footprint (only Nokogiri and Zeitwerk)
- Regular dependency updates via Renovate
- Security scanning of dependencies in CI pipeline
- Pinned versions for reproducible builds

## Development Workflow

### Getting Started
1. Clone the repository
2. Run `bundle install` to install dependencies
3. Run `bin/rspecs` to verify the test suite passes
4. Run `bundle exec rubocop` to check code style
5. Make changes following the style guidelines
6. Add tests for new functionality
7. Run the full test suite before committing

### Contributing Guidelines
- Keep commits focused and atomic
- Use present-tense, descriptive commit messages
- Ensure CI passes before requesting review
- Update documentation for API changes
- Add integration tests for new CLI commands
- Follow existing code patterns and conventions

### Release Process
1. Update version in `lib/llm_docs_builder/version.rb`
2. Update CHANGELOG.md with release notes
3. Create git tag matching the version
4. Push tag to trigger automated builds
5. Verify gem and Docker image publication
6. Update documentation and examples as needed