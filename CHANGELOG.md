# Changelog

## 0.7.0 (2025-10-09)
- [Feature] **Advanced Token Optimization** - Added 8 new compression options to reduce token consumption:
  - `remove_code_examples`: Remove code blocks and inline code
  - `remove_images`: Remove all image syntax
  - `simplify_links`: Simplify verbose link text (e.g., "Click here to see the docs" → "docs")
  - `remove_blockquotes`: Remove blockquote formatting while preserving content
  - `generate_toc`: Generate table of contents from headings with anchor links
  - `custom_instruction`: Inject AI context messages at document top
  - `remove_stopwords`: Remove common stopwords from prose (preserves code blocks)
  - `remove_duplicates`: Remove duplicate paragraphs using fuzzy matching
- [Feature] **Compression Presets** - 6 built-in presets for easy usage:
  - `conservative`: 15-25% reduction (safest transformations)
  - `moderate`: 30-45% reduction (balanced approach)
  - `aggressive`: 50-70% reduction (maximum compression)
  - `documentation`: 35-50% reduction (preserves code examples)
  - `tutorial`: 20% reduction (minimal compression for learning materials)
  - `api_reference`: 40% reduction (optimized for API documentation)
- [Enhancement] **Refactored Architecture** - Split monolithic `MarkdownTransformer` into focused transformer classes following SRP:
  - `BaseTransformer`: Common interface for all transformers
  - `LinkTransformer`: Link expansion, URL conversion, link simplification
  - `ContentCleanupTransformer`: All removal operations
  - `EnhancementTransformer`: TOC generation and custom instructions
  - `WhitespaceTransformer`: Whitespace normalization
  - `MarkdownTransformer`: Pipeline orchestrator
- [Enhancement] Added `TextCompressor` class for advanced text compression (stopwords, duplicates).
- [Enhancement] Added `TokenEstimator` class for token count estimation.
- [Enhancement] Added `OutputFormatter` class for formatted output (extracted from CLI).
- [Enhancement] Added `CompressionPresets` class with preset configurations.
- [Enhancement] Custom instructions now adapt to blockquote removal setting (no blockquote format when `remove_blockquotes: true`).
- [Enhancement] Updated `Config#merge_with_options` to support all new compression options.
- [Testing] Added 20 new integration tests for compression features and presets.
- [Testing] Added automatic config file backup/restore in test suite to prevent interference.
- [Testing] All 110 tests passing with 79.44% code coverage.
- [Documentation] **Shortened README.md by 47%** (729 → 381 lines) while adding all new features.
- [Documentation] Added comprehensive compression examples and use cases.
- [Documentation] Added preset comparison table showing what each preset does.

## 0.6.0 (2025-10-09)
- [Breaking] **Project renamed from `llms-txt-ruby` to `llm-docs-builder`** to better reflect expanded functionality beyond just llms.txt generation.
  - Gem name: `llms-txt-ruby` → `llm-docs-builder`
  - Module name: `LlmsTxt` → `LlmDocsBuilder`
  - CLI command: `llms-txt` → `llm-docs-builder`
  - Config file: `llms-txt.yml` → `llm-docs-builder.yml`
  - Docker images: `mensfeld/llms-txt-ruby` → `mensfeld/llm-docs-builder`
  - Repository: `llms-txt-ruby` → `llm-docs-builder`
  - Updated all documentation, examples, and tests
- [Feature] Added Docker support for easy CLI usage without Ruby installation.
  - Multi-stage Dockerfile for minimal image size (~78MB)
  - Multi-architecture support (linux/amd64, linux/arm64)
  - Published to Docker Hub (`mensfeld/llm-docs-builder`) and GitHub Container Registry
  - GitHub Actions workflow for automated Docker builds and publishing
  - Comprehensive Docker usage documentation with examples for all commands
  - CI/CD integration examples (GitHub Actions, GitLab CI, Jenkins)
- [Feature] Added `compare` command to measure context window savings by comparing content sizes between human and AI versions.
  - Compare remote URL with different User-Agents (human browser vs AI bot)
  - Compare remote URL with local markdown file
  - Display reduction percentage, bytes saved, and compression factor
  - Support for custom User-Agents and verbose output
- [Enhancement] Added `Comparator` class with comprehensive specs for HTTP fetching and size comparison.
- [Enhancement] Added `-u/--url` and `-f/--file` CLI flags for compare command.
- [Security] Added redirect depth limiting (MAX_REDIRECTS = 10) to prevent infinite redirect loops.
- [Security] Added URL validation to reject non-HTTP/HTTPS schemes (prevents file://, javascript:, ftp://, etc.).
- [Security] Added URL format validation to ensure proper host and scheme presence.
- [Enhancement] Added verbose redirect logging to show redirect chains when --verbose flag is used.

## 0.2.0 (2025-10-07)
- [Breaking] Removed positional argument support for all CLI commands. All file paths must now be specified using flags:
  - `transform`: use `-d/--docs` flag instead of positional argument
  - `parse`: use `-d/--docs` flag instead of positional argument (defaults to `llms.txt` if not specified)
  - `validate`: use `-d/--docs` flag instead of positional argument (defaults to `llms.txt` if not specified)
- [Enhancement] Improved CLI consistency by requiring explicit flags for all file paths.
- [Enhancement] Added comprehensive CLI integration tests in `spec/integrations/` directory.
  - Each command has its own dedicated integration test file
  - Tests verify actual CLI binary execution, not just Ruby API
  - All tests (unit and integration) run together with `bin/rspecs`
- [Enhancement] Added convenient test runner script `bin/rspecs` for running all tests.
- [Enhancement] Added comprehensive YARD documentation to all CLI methods.
- [Enhancement] Resolved all RuboCop offenses (0 offenses detected).
- [Fix] Fixed validator bug where `each_value` was incorrectly called on Array.

## 0.1.3 (2025-10-07)
- [Fix] Fixed `transform` command to accept file path from `-d/--docs` flag in addition to positional arguments.

## 0.1.2 (2025-10-07)
- [Fix] Fixed CLI error handling to use correct `LlmsTxt::Errors::BaseError` instead of non-existent `LlmsTxt::Error`.
- [Enhancement] Extracted CLI class to `lib/llms_txt/cli.rb` for better testability.
- [Enhancement] Added comprehensive CLI error handling specs.

## 0.1.1 (2025-10-07)
- [Change] Updated repository metadata to use `master` branch instead of `main`.

## 0.1.0 (2025-10-07)
- [Feature] Generate `llms.txt` files from markdown documentation.
- [Feature] Transform individual markdown files to be AI-friendly.
- [Feature] Bulk transformation of entire documentation directories.
- [Feature] CLI with commands: `generate`, `transform`, `bulk-transform`, `parse`, `validate`.
- [Feature] Configuration file support (`llms-txt.yml`).
- [Feature] Automatic link expansion from relative to absolute URLs.
- [Feature] File prioritization (README first, then guides, APIs, etc.).
- [Feature] Exclusion patterns for bulk transformations.
- [Feature] Ruby API for programmatic usage.
