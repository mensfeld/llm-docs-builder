# Repository Guidelines

## Project Structure & Module Organization
Core gem code lives in `lib/llm_docs_builder`, with single-responsibility modules such as `generator.rb`, `validator.rb`, and the CLI glue in `cli.rb`. Shared entrypoint `lib/llm_docs_builder.rb` wires dependencies. Executables reside in `bin/`: `llm-docs-builder` boots the CLI, while `rspecs` runs the full test matrix. Specs mirror library files under `spec/` with command-level coverage in `spec/integrations`. Static assets (logos, diff screenshots) are in `misc/`. Example configuration templates live at `llm-docs-builder.yml.example`.

## Build, Test, and Development Commands
- `bundle install` — sync gem dependencies defined in `Gemfile`.
- `bundle exec rake` — default task; runs RSpec and RuboCop together.
- `bundle exec rspec` or `bin/rspecs` — execute unit and integration specs with doc formatter.
- `bundle exec rubocop` — enforce the Ruby style guide; mirrors CI.
- `bin/llm-docs-builder transform --docs README.md` — smoke-test the CLI against a local file.

## Coding Style & Naming Conventions
Target Ruby 3.2 with two-space indentation and trailing newline. Prefer single-quoted strings; enable `# frozen_string_literal: true` headers on Ruby files. Keep lines ≤120 characters except where the RuboCop config allows. Use descriptive module/class names (e.g., `LlmDocsBuilder::Generator`) and predicate methods ending with `?` when returning booleans. Place supporting fixtures in `spec/support` if added, and name files after the class they extend.

## Testing Guidelines
RSpec is the sole testing framework. Name files `*_spec.rb` and align describe blocks with constant paths. Integration scenarios belong in `spec/integrations` to capture CLI behaviors. SimpleCov is enabled by default for line and branch coverage; export `SIMPLECOV=false` for quick local runs. Persist example statuses with the automatically managed `spec/examples.txt`.

## Commit & Pull Request Guidelines
Keep commit subjects short, present-tense, and focused (e.g., `Align CLI config (#27)`). Group related changes together so `git log` remains readable. Pull requests should describe motivation, summarize behavioral impact, link related issues or discussions, and include CLI output or screenshots when touching generated docs. Ensure CI passes (`bundle exec rake`) before requesting review, and note any follow-up work in the PR description.
