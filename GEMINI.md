# llm-docs-builder

## Project Overview

`llm-docs-builder` is a Ruby-based command-line tool designed to optimize Markdown documentation for Large Language Models (LLMs) and Retrieval-Augmented Generation (RAG) systems. Its primary goal is to reduce the token count of documentation by removing unnecessary content, normalizing links, and enhancing documents for better RAG retrieval. The tool can be used as a Ruby library or as a standalone CLI.

The project is structured as a Ruby gem, with the main source code located in the `lib` directory. It uses `nokogiri` for HTML parsing, `rspec` for testing, and `rubocop` for code linting. The command-line interface is implemented in `lib/llm_docs_builder/cli.rb` and provides several commands for interacting with the tool.

## Building and Running

### Dependencies

The project uses [Bundler](https://bundler.io/) to manage its Ruby dependencies. To install the required gems, run:

```bash
bundle install
```

### Running Tests

The project uses [RSpec](https://rspec.info/) for testing. To run the test suite, use the following command:

```bash
bundle exec rspec
```

### Linting

The project uses [RuboCop](https://rubocop.org/) for static code analysis and linting. To check the code for any style violations, run:

```bash
bundle exec rubocop
```

### Rake Tasks

The `Rakefile` provides a convenient way to run both tests and linting with a single command:

```bash
bundle exec rake
```

### Running the CLI

The main executable is located in the `bin` directory. You can run the CLI tool using `bundle exec`:

```bash
bundle exec llm-docs-builder --help
```

## Development Conventions

*   **Testing:** The project has a comprehensive test suite in the `spec` directory. All new features and bug fixes should be accompanied by corresponding tests.
*   **Linting:** The project follows the coding style enforced by RuboCop. Before committing any changes, make sure to run `bundle exec rubocop` and fix any reported offenses.
*   **Documentation:** The code is well-documented with comments and examples. Please maintain this standard when adding new code.
