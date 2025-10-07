# Integration Tests

This directory contains integration tests for the llms-txt CLI. These tests verify the actual CLI binary execution, not just the Ruby API.

## Running Tests

All tests (unit and integration) run together with a single command:

```bash
# Run all tests
bin/rspec

# Or with bundle exec
bundle exec rspec

# Run a specific integration test file
bundle exec rspec spec/integrations/generate_command_spec.rb

# Run with documentation format for detailed output
bundle exec rspec --format documentation
```

## Test Files

Each CLI command has its own dedicated integration test file:

- `generate_command_spec.rb` - Tests for `llms-txt generate`
- `transform_command_spec.rb` - Tests for `llms-txt transform`
- `bulk_transform_command_spec.rb` - Tests for `llms-txt bulk-transform`
- `parse_command_spec.rb` - Tests for `llms-txt parse`
- `validate_command_spec.rb` - Tests for `llms-txt validate`
- `version_command_spec.rb` - Tests for `llms-txt version` and error handling

## What These Tests Verify

Integration tests verify end-to-end functionality by:

1. **Actual CLI Execution** - Uses `Open3.capture3` to run the actual `bin/llms-txt` binary
2. **Real File Operations** - Creates temporary files and directories, runs transformations
3. **Exit Codes** - Verifies proper exit codes for success (0) and failure (1)
4. **Output Verification** - Checks stdout/stderr for expected messages
5. **Error Handling** - Tests that errors are properly caught and displayed

## Example Test Structure

```ruby
it 'generates llms.txt from documentation directory' do
  # Setup - create test files
  File.write(File.join(temp_dir, 'README.md'), "# Test\n\nContent")

  # Execute - run actual CLI command
  stdout, _stderr, status = run_cli('generate', '--docs', temp_dir, '--output', output_file)

  # Verify - check results
  expect(status.success?).to be true
  expect(File.exist?(output_file)).to be true
  expect(File.read(output_file)).to include('# Test')
end
```

## Why Integration Tests?

While unit tests verify individual components work correctly, integration tests ensure:

- The CLI binary can be executed successfully
- Command-line argument parsing works correctly
- File I/O operations work in real scenarios
- Error messages are user-friendly
- The complete user workflow functions as expected

These tests also serve as **living documentation** showing how to use the CLI.
