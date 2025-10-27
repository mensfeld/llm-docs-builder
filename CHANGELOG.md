# Changelog

## 0.10.0 (2025-10-27)
- [Feature] **llms.txt Specification Compliance** - Updated output format to fully comply with the llms.txt specification from llmstxt.org.
  - **Metadata Format**: Metadata now appears within the description field using parentheses and comma separators: `- [title](url): description (tokens:450, updated:2025-10-13, priority:high)`
  - **Optional Descriptions**: Parser now correctly handles links without descriptions: `- [title](url)` per spec
  - **Multi-Section Support**: Documents automatically organized into `Documentation`, `Examples`, and `Optional` sections based on priority
  - **Body Content Support**: Added optional `body` config parameter for custom content between description and sections
  - Priority-based categorization: 1-3 → Documentation, 4-5 → Examples, 6-7 → Optional
  - Empty sections are automatically omitted from output
  - Updated parser regex from `/^[-*]\s*\[([^\]]+)\]\(([^)]+)\):\s*(.*)$/m` to `/^[-*]\s*\[([^\]]+)\]\(([^)]+)\)(?::\s*([^\n]*))?$/` to make descriptions optional
  - Fixed multiline regex greedy matching issue that was capturing only one link per section
- [Test] Added comprehensive test suite for spec compliance (8 new parser tests, 7 new generator tests)
- [Docs] Updated README with multi-section organization examples and body content usage
- **Breaking Change**: Metadata format has changed from `tokens:450 updated:2025-10-13` to `(tokens:450, updated:2025-10-13)` for spec compliance

## 0.9.4 (2025-10-27)
- [Feature] **Auto-Exclude Hidden Directories** - Hidden directories (starting with `.`) are now automatically excluded by default to prevent noise from `.git`, `.lint`, `.github`, etc.
  - Adds `include_hidden: false` as default behavior
  - Set `include_hidden: true` in config to include hidden directories if needed
  - Uses `Find.prune` for efficient directory tree traversal
  - Prevents scanning of common directories like `.lint`, `.gh`, `.git`, `node_modules` (if hidden)
  - Fixed bug where root directory `.` was being pruned when used as docs_path
- [Fix] **Excludes Pattern Matching** - Fixed fnmatch pattern handling for better glob pattern support.
  - Fixed `**/.dir/**` patterns now correctly match root-level directories
  - Normalized patterns ending with `/**` to `/**/*` for proper fnmatch behavior
  - Handles `**/` prefix matching for zero-directory cases
  - Fixed relative path calculation to avoid "different prefix" errors
- [Test] Added unit tests for hidden directory exclusion feature (5 tests)
- [Test] Added integration tests for hidden directory behavior (3 tests)

## 0.9.3 (2025-10-27)
- [Fix] **Generate Command Excludes Support** - The `generate` command now properly respects the `excludes` configuration option to filter out files from llms.txt generation.
  - Added `should_exclude?` method to Generator class that matches files against glob patterns
  - Supports both simple patterns (e.g., `draft.md`) and glob patterns (e.g., `**/private/**`, `draft-*.md`)
  - Uses `File.fnmatch` with `FNM_PATHNAME` and `FNM_DOTMATCH` flags for proper pattern matching
  - Checks patterns against both absolute and relative paths from docs_path
  - Excludes configuration works consistently with bulk-transform command
- [Fix] **Token Count from Transformed Content** - Token counts in metadata now accurately reflect the actual content after applying transformations.
  - Token count is now calculated from transformed content when any transformation options are enabled
  - Adds `has_transformations?` helper method to detect if transformations are active
  - Ensures token metadata represents the actual size of processed content, not raw files
  - Falls back to raw content token count when no transformations are enabled
- [Fix] **Boolean Config Options** - Fixed config merging bug where explicitly setting transformation options to `false` in YAML was being overridden to `true`.
  - Updated `Config#merge_with_options` to properly handle `false` values for boolean options
  - Fixed the `|| true` pattern that was incorrectly treating `false` config values as falsy
  - Now correctly uses `!self['option'].nil?` check before falling back to defaults
  - Applies to all boolean transformation options: `remove_comments`, `normalize_whitespace`, `remove_badges`, `remove_frontmatter`
- [Test] Added comprehensive unit tests for excludes functionality in Generator
- [Test] Added integration tests for generate command with excludes and token counting

## 0.9.2 (2025-10-17)
- [Fix] Tackle one more block boundaries tracking edge-case.

## 0.9.1 (2025-10-17)
- [Fix] Fixed HeadingTransformer incorrectly treating hash symbols in code blocks as headings.
  - Now properly tracks code block boundaries (fenced with ``` or ~~~)
  - Fixed regex pattern from `/^```|^~~~/` to `/^(```|~~~)/` for correct operator precedence
  - Skips heading processing for lines inside code blocks
  - Prevents Ruby/Python/Shell comments from being interpreted as markdown headings
  - Added 5 comprehensive test cases covering multiple scenarios to prevent regression
  - Skips heading processing for lines inside code blocks
  - Prevents Ruby/Python/Shell comments from being interpreted as markdown headings
  - Added comprehensive test coverage for code block handling

## 0.9.0 (2025-10-17)
- [Feature] **No AI Version Detection** - The `compare` command now detects when websites don't serve AI-optimized versions.
  - Triggers when reduction is <5% (nearly identical content for human and AI User-Agents)
  - Displays prominent warning: "WARNING: NO DEDICATED AI VERSION DETECTED"
  - Shows potential savings estimates based on typical 83% reduction rate
  - Provides page-specific calculations (estimated token savings, potential size)
  - Includes implementation guide with actionable steps
  - Helps identify opportunities to optimize documentation
- [Enhancement] Updated `OutputFormatter#display_comparison_results` to include marketing message for unoptimized sites.
- [Enhancement] Added utility script `probe_karafka_simple.rb` for batch comparison testing.

## 0.8.2 (2025-10-17)
- [Fix] Fixed Docker workflow test to properly invoke help command (use `generate --help` instead of `--help`).

## 0.8.1 (2025-10-17)
- [Enhancement] Ship the docker container.

## 0.8.0 (2025-10-14)
- [Feature] **RAG Enhancement: Heading Normalization** - Transform headings to include hierarchical context for better RAG retrieval.
  - Adds parent context to H2-H6 headings (e.g., "Configuration / Consumer Settings / auto_offset_reset")
  - Makes each section self-contained when documents are chunked
  - Configurable separator (default: " / ")
  - Enable with `normalize_headings: true`
  - Perfect for vector databases and RAG systems
- [Feature] **RAG Enhancement: Enhanced llms.txt Metadata** - Generate enriched llms.txt files with machine-readable metadata.
  - Token counts per document (helps AI agents manage context windows)
  - Last modified timestamps (helps prefer recent docs)
  - Priority labels: high/medium/low (helps guide which docs to fetch first)
  - Optional compression ratios (shows optimization effectiveness)
  - Enable with `include_metadata: true`, `include_tokens: true`, `include_timestamps: true`, `include_priority: true`
- [Enhancement] Added `HeadingTransformer` class with comprehensive heading hierarchy tracking.
- [Enhancement] Added priority calculation in Generator (README=high, getting started=high, tutorials=medium, etc.).
- [Enhancement] Updated `Config#merge_with_options` to support all new RAG options.
- [Testing] Added 10 comprehensive tests for HeadingTransformer covering edge cases.
- [Testing] All 303 tests passing with 96.94% line coverage and 85.59% branch coverage.
- [Documentation] Added "RAG Enhancement Features" section to README with examples and use cases.
- [Documentation] Added detailed implementation guide in RAG_FEATURES.md.
- [Documentation] Added example RAG configuration in examples/rag-config.yml.

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
