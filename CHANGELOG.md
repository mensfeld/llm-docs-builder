# Changelog

## 0.2.0 (2025-10-07)
- [Breaking] Removed positional argument support for all CLI commands. All file paths must now be specified using flags:
  - `transform`: use `-d/--docs` flag instead of positional argument
  - `parse`: use `-d/--docs` flag instead of positional argument (defaults to `llms.txt` if not specified)
  - `validate`: use `-d/--docs` flag instead of positional argument (defaults to `llms.txt` if not specified)
- [Enhancement] Improved CLI consistency by requiring explicit flags for all file paths.
- [Enhancement] Added comprehensive CLI integration tests in `spec/integration/` directory.
  - Tests are excluded from default RSpec runs
  - Run with `bundle exec rspec --tag integration` to execute
  - Each command has its own dedicated integration test file
  - Tests verify actual CLI binary execution, not just Ruby API
- [Enhancement] Added convenient test runner scripts:
  - `bin/rspec` - Runs unit tests only
  - `bin/integration` - Runs integration tests only
- [Enhancement] Updated CI workflow to run both unit and integration tests separately.

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
