# frozen_string_literal: true

require 'llm_docs_builder/cli'

RSpec.describe LlmDocsBuilder::CLI do
  describe '.run class method' do
    it 'creates instance and calls run' do
      expect_any_instance_of(described_class).to receive(:run).with(['version'])
      described_class.run(['version'])
    end
  end

  describe '#run' do
    context 'when LlmDocsBuilder::Errors::GenerationError is raised' do
      it 'catches the error and exits with status 1' do
        cli = described_class.new

        # Mock the generate method to raise an error
        allow(LlmDocsBuilder).to receive(:generate_from_docs).and_raise(
          LlmDocsBuilder::Errors::GenerationError.new('Test generation error')
        )

        expect do
          cli.run(['generate', '--docs', 'nonexistent', '--output', 'test.txt'])
        end.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'displays the error message' do
        cli = described_class.new

        allow(LlmDocsBuilder).to receive(:generate_from_docs).and_raise(
          LlmDocsBuilder::Errors::GenerationError.new('Test generation error')
        )

        expect do
          expect do
            cli.run(['generate', '--docs', 'nonexistent', '--output', 'test.txt'])
          end.to output(/Error: Test generation error/).to_stdout
        end.to raise_error(SystemExit)
      end
    end

    context 'when LlmDocsBuilder::Errors::ValidationError is raised' do
      it 'catches the error and exits with status 1' do
        cli = described_class.new

        allow(LlmDocsBuilder).to receive(:generate_from_docs).and_raise(
          LlmDocsBuilder::Errors::ValidationError.new('Test validation error')
        )

        expect do
          cli.run(['generate', '--docs', 'nonexistent', '--output', 'test.txt'])
        end.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end
    end

    context 'when bulk_transform raises an error' do
      let(:temp_dir) { Dir.mktmpdir }

      after do
        FileUtils.rm_rf(temp_dir)
      end

      it 'catches LlmDocsBuilder::Errors::BaseError in bulk_transform rescue block' do
        cli = described_class.new

        # Create a valid directory
        File.write(File.join(temp_dir, 'test.md'), '# Test')

        # Mock bulk_transform to raise an error
        allow(LlmDocsBuilder).to receive(:bulk_transform).and_raise(
          LlmDocsBuilder::Errors::GenerationError.new('Bulk transformation failed')
        )

        expect do
          cli.run(['bulk-transform', '--docs', temp_dir])
        end.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'displays error message during bulk transformation' do
        cli = described_class.new

        File.write(File.join(temp_dir, 'test.md'), '# Test')

        allow(LlmDocsBuilder).to receive(:bulk_transform).and_raise(
          LlmDocsBuilder::Errors::GenerationError.new('Bulk transformation failed')
        )

        expect do
          expect do
            cli.run(['bulk-transform', '--docs', temp_dir])
          end.to output(/Error during bulk transformation: Bulk transformation failed/).to_stdout
        end.to raise_error(SystemExit)
      end
    end

    context 'transform command' do
      let(:temp_file) do
        file = Tempfile.new(['test', '.md'])
        file.write("# Test\n\nSome content")
        file.close
        file
      end

      let(:output_file) do
        file = Tempfile.new(['output', '.md'])
        file.close
        file
      end

      after do
        temp_file.unlink
        output_file.unlink
      end

      it 'accepts file path from -d/--docs flag' do
        cli = described_class.new

        expect do
          cli.run(['transform', '-d', temp_file.path, '-o', output_file.path])
        end.not_to raise_error

        expect(File.exist?(output_file.path)).to be true
      end

      it 'requires -d/--docs flag for file path' do
        cli = described_class.new

        expect do
          cli.run(['transform', '-o', output_file.path])
        end.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'displays error when file path required' do
        cli = described_class.new

        expect do
          expect do
            cli.run(['transform', '-o', output_file.path])
          end.to output(/File path required/).to_stdout
        end.to raise_error(SystemExit)
      end

      it 'displays error when file not found' do
        cli = described_class.new

        expect do
          expect do
            cli.run(['transform', '-d', 'nonexistent.md', '-o', output_file.path])
          end.to output(/File not found/).to_stdout
        end.to raise_error(SystemExit)
      end

      it 'outputs to stdout when no output file specified' do
        cli = described_class.new

        expect do
          cli.run(['transform', '-d', temp_file.path])
        end.to output(/# Test/).to_stdout
      end

      it 'displays verbose output when verbose flag is set' do
        cli = described_class.new

        expect do
          cli.run(['transform', '-d', temp_file.path, '-o', output_file.path, '-v'])
        end.to output(/Transforming/).to_stdout
      end

      it 'saves to output file and displays success message' do
        cli = described_class.new

        expect do
          cli.run(['transform', '-d', temp_file.path, '-o', output_file.path])
        end.to output(/Transformed content saved to/).to_stdout

        expect(File.read(output_file.path)).to include('# Test')
      end
    end

    context 'bulk-transform command' do
      let(:temp_dir) { Dir.mktmpdir }

      after do
        FileUtils.rm_rf(temp_dir)
      end

      it 'displays message when no markdown files found' do
        cli = described_class.new

        expect do
          cli.run(['bulk-transform', '--docs', temp_dir])
        end.to output(/No markdown files found/).to_stdout
      end

      it 'displays verbose output with suffix and excludes' do
        cli = described_class.new
        File.write(File.join(temp_dir, 'test.md'), '# Test')

        config_file = File.join(temp_dir, 'llm-docs-builder.yml')
        File.write(config_file, "suffix: .ai\nexcludes:\n  - '**/draft/**'")

        expect do
          cli.run(['bulk-transform', '--docs', temp_dir, '-c', config_file, '-v'])
        end.to output(/Using suffix: \.ai/).to_stdout
      end

      it 'requires directory path to be a directory' do
        cli = described_class.new
        file = Tempfile.new(['test', '.md'])
        file.write('# Test')
        file.close

        expect do
          cli.run(['bulk-transform', '--docs', file.path])
        end.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end

        file.unlink
      end

      it 'displays error when path not found' do
        cli = described_class.new

        expect do
          expect do
            cli.run(['bulk-transform', '--docs', 'nonexistent_dir'])
          end.to output(/Documentation path not found/).to_stdout
        end.to raise_error(SystemExit)
      end

      it 'displays error when path is not a directory' do
        cli = described_class.new
        file = Tempfile.new(['test', '.md'])
        file.write('# Test')
        file.close

        expect do
          expect do
            cli.run(['bulk-transform', '--docs', file.path])
          end.to output(/Path must be a directory/).to_stdout
        end.to raise_error(SystemExit)

        file.unlink
      end

      it 'displays success message with file list in non-verbose mode' do
        cli = described_class.new
        File.write(File.join(temp_dir, 'test.md'), '# Test')

        expect do
          cli.run(['bulk-transform', '--docs', temp_dir])
        end.to output(/Successfully transformed 1 files/).to_stdout
      end
    end

    context 'generate command' do
      let(:temp_dir) { Dir.mktmpdir }

      after do
        FileUtils.rm_rf(temp_dir)
      end

      it 'displays validation warnings in verbose mode when invalid' do
        cli = described_class.new
        File.write(File.join(temp_dir, 'test.md'), '# Test')
        output = File.join(temp_dir, 'llms.txt')

        # Create invalid llms.txt content
        allow(LlmDocsBuilder).to receive(:generate_from_docs).and_return("Invalid content\n")

        expect do
          cli.run(['generate', '--docs', temp_dir, '-o', output, '-v'])
        end.to output(/Validation warnings/).to_stdout
      end

      it 'displays valid message in verbose mode when valid' do
        cli = described_class.new
        File.write(File.join(temp_dir, 'test.md'), '# Test')
        output = File.join(temp_dir, 'llms.txt')

        valid_content = "# Test Project\n\nDescription\n\n## Documentation\n- [Test](https://example.com/test.md)"
        allow(LlmDocsBuilder).to receive(:generate_from_docs).and_return(valid_content)

        expect do
          cli.run(['generate', '--docs', temp_dir, '-o', output, '-v'])
        end.to output(/Valid llms\.txt format/).to_stdout
      end
    end

    context 'parse command' do
      let(:temp_file) do
        file = Tempfile.new(['llms', '.txt'])
        file.write("# Test\n\nDescription\n\n## Documentation\n- [Link](http://example.com)")
        file.close
        file
      end

      after do
        temp_file.unlink
      end

      it 'displays verbose information' do
        cli = described_class.new

        expect do
          cli.run(['parse', '--docs', temp_file.path, '-v'])
        end.to output(/Title: Test/).to_stdout
      end

      it 'runs silently in non-verbose mode' do
        cli = described_class.new

        expect do
          cli.run(['parse', '--docs', temp_file.path])
        end.not_to output.to_stdout
      end

      it 'defaults to llms.txt when no file specified' do
        cli = described_class.new

        expect do
          cli.run(['parse'])
        end.to raise_error(SystemExit) # File not found
      end

      it 'displays error when file not found' do
        cli = described_class.new

        expect do
          expect do
            cli.run(['parse', '--docs', 'nonexistent.txt'])
          end.to output(/File not found/).to_stdout
        end.to raise_error(SystemExit)
      end
    end

    context 'compare command' do
      it 'requires URL parameter' do
        cli = described_class.new

        expect do
          cli.run(['compare'])
        end.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'displays usage examples when URL not provided' do
        cli = described_class.new

        expect do
          expect do
            cli.run(['compare'])
          end.to output(/Examples:/).to_stdout
        end.to raise_error(SystemExit)
      end

      it 'handles comparison errors gracefully' do
        cli = described_class.new

        allow_any_instance_of(LlmDocsBuilder::Comparator).to receive(:compare).and_raise(
          LlmDocsBuilder::Errors::GenerationError.new('Network error')
        )

        expect do
          expect do
            cli.run(['compare', '--url', 'https://example.com/page'])
          end.to output(/Error during comparison: Network error/).to_stdout
        end.to raise_error(SystemExit)
      end

      it 'successfully compares with URL and local file' do
        cli = described_class.new
        temp_file = Tempfile.new(['test', '.md'])
        temp_file.write('# Test content')
        temp_file.close

        # Mock the comparator to return success result
        allow_any_instance_of(LlmDocsBuilder::Comparator).to receive(:compare).and_return(
          human_size: 1000,
          ai_size: 500,
          reduction_bytes: 500,
          reduction_percent: 50,
          factor: 2.0,
          human_tokens: 250,
          ai_tokens: 125,
          token_reduction: 125,
          token_reduction_percent: 50,
          human_source: 'https://example.com/page',
          ai_source: temp_file.path
        )

        expect do
          cli.run(['compare', '--url', 'https://example.com/page', '--file', temp_file.path])
        end.not_to raise_error

        temp_file.unlink
      end

      it 'accepts -u and -f flags for URL and file' do
        cli = described_class.new
        temp_file = Tempfile.new(['test', '.md'])
        temp_file.write('# Test')
        temp_file.close

        allow_any_instance_of(LlmDocsBuilder::Comparator).to receive(:compare).and_return(
          human_size: 100,
          ai_size: 50,
          reduction_bytes: 50,
          reduction_percent: 50,
          factor: 2.0,
          human_tokens: 25,
          ai_tokens: 12,
          token_reduction: 13,
          token_reduction_percent: 52,
          human_source: 'https://example.com',
          ai_source: temp_file.path
        )

        expect do
          cli.run(['compare', '-u', 'https://example.com', '-f', temp_file.path])
        end.not_to raise_error

        temp_file.unlink
      end
    end

    context 'validate command' do
      let(:temp_file) do
        file = Tempfile.new(['llms', '.txt'])
        file.write("# Test\n\nDescription\n\n## Documentation\n- [Link](http://example.com)")
        file.close
        file
      end

      after do
        temp_file.unlink
      end

      it 'displays errors when file is invalid' do
        cli = described_class.new
        invalid_file = Tempfile.new(['invalid', '.txt'])
        invalid_file.write("Invalid content")
        invalid_file.close

        expect do
          expect do
            cli.run(['validate', '--docs', invalid_file.path])
          end.to output(/Invalid llms\.txt file/).to_stdout
        end.to raise_error(SystemExit)

        invalid_file.unlink
      end

      it 'displays errors list when file is invalid' do
        cli = described_class.new
        invalid_file = Tempfile.new(['invalid', '.txt'])
        invalid_file.write("Invalid content")
        invalid_file.close

        expect do
          expect do
            cli.run(['validate', '--docs', invalid_file.path])
          end.to output(/Errors:/).to_stdout
        end.to raise_error(SystemExit)

        invalid_file.unlink
      end

      it 'displays success message when valid' do
        cli = described_class.new

        expect do
          cli.run(['validate', '--docs', temp_file.path])
        end.to output(/Valid llms\.txt file/).to_stdout
      end

      it 'defaults to llms.txt when no file specified' do
        cli = described_class.new

        expect do
          cli.run(['validate'])
        end.to raise_error(SystemExit) # File not found
      end

      it 'displays error when file not found' do
        cli = described_class.new

        expect do
          expect do
            cli.run(['validate', '--docs', 'nonexistent.txt'])
          end.to output(/File not found/).to_stdout
        end.to raise_error(SystemExit)
      end
    end

    context 'version command' do
      it 'displays version via command' do
        cli = described_class.new

        expect do
          cli.run(['version'])
        end.to output(/llm-docs-builder version/).to_stdout
      end

      it 'displays version with --version flag and outputs version' do
        expect do
          expect do
            described_class.new.run(['generate', '--version'])
          end.to output(/llm-docs-builder version/).to_stdout
        end.to raise_error(SystemExit)
      end

      it 'displays help with --help flag and outputs usage' do
        expect do
          expect do
            described_class.new.run(['generate', '--help'])
          end.to output(/Usage:/).to_stdout
        end.to raise_error(SystemExit)
      end
    end

    context 'unknown command' do
      it 'displays error for unknown command' do
        cli = described_class.new

        expect do
          expect do
            cli.run(['invalid-command'])
          end.to output(/Unknown command: invalid-command/).to_stdout
        end.to raise_error(SystemExit)
      end
    end

    context 'StandardError handling' do
      it 'displays unexpected error without backtrace when not verbose' do
        cli = described_class.new
        allow(LlmDocsBuilder).to receive(:generate_from_docs).and_raise(StandardError.new('Unexpected'))

        expect do
          expect do
            cli.run(['generate', '--docs', '.'])
          end.to output(/Unexpected error: Unexpected/).to_stdout
        end.to raise_error(SystemExit)
      end

      it 'displays backtrace when verbose is enabled' do
        cli = described_class.new
        allow(LlmDocsBuilder).to receive(:generate_from_docs).and_raise(StandardError.new('Unexpected'))

        expect do
          expect do
            cli.run(['generate', '--docs', '.', '-v'])
          end.to output(/Unexpected error: Unexpected/).to_stdout
        end.to raise_error(SystemExit)
      end
    end
  end
end
