# Changelog

## Unreleased
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
