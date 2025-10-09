# frozen_string_literal: true

require 'llm_docs_builder/cli'

RSpec.describe LlmDocsBuilder::CLI do
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
    end
  end
end
