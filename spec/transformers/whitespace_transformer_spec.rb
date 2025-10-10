# frozen_string_literal: true

RSpec.describe LlmDocsBuilder::Transformers::WhitespaceTransformer do
  subject(:transformer) { described_class.new }

  describe '#transform' do
    context 'with normalize_whitespace option' do
      it 'removes trailing whitespace from lines' do
        content = "Line 1   \nLine 2  \nLine 3\n"
        result = transformer.transform(content, normalize_whitespace: true)

        expect(result).to eq("Line 1\nLine 2\nLine 3")
      end

      it 'reduces multiple consecutive blank lines to maximum of 2' do
        content = "Line 1\n\n\n\n\nLine 2"
        result = transformer.transform(content, normalize_whitespace: true)

        expect(result).to eq("Line 1\n\n\nLine 2")
      end

      it 'handles 4 consecutive blank lines' do
        content = "Line 1\n\n\n\nLine 2"
        result = transformer.transform(content, normalize_whitespace: true)

        expect(result).to eq("Line 1\n\n\nLine 2")
      end

      it 'handles 10 consecutive blank lines' do
        content = "Line 1\n\n\n\n\n\n\n\n\n\nLine 2"
        result = transformer.transform(content, normalize_whitespace: true)

        expect(result).to eq("Line 1\n\n\nLine 2")
      end

      it 'preserves single blank lines' do
        content = "Line 1\n\nLine 2"
        result = transformer.transform(content, normalize_whitespace: true)

        expect(result).to eq("Line 1\n\nLine 2")
      end

      it 'preserves double blank lines' do
        content = "Line 1\n\n\nLine 2"
        result = transformer.transform(content, normalize_whitespace: true)

        expect(result).to eq("Line 1\n\n\nLine 2")
      end

      it 'trims leading whitespace' do
        content = "\n\n  Line 1\n  Line 2"
        result = transformer.transform(content, normalize_whitespace: true)

        expect(result).to start_with('Line 1')
      end

      it 'trims trailing whitespace from document' do
        content = "Line 1\nLine 2\n\n  \n  "
        result = transformer.transform(content, normalize_whitespace: true)

        expect(result).to end_with('Line 2')
      end

      it 'handles tabs as trailing whitespace' do
        content = "Line 1\t\nLine 2"
        result = transformer.transform(content, normalize_whitespace: true)

        expect(result).to include("Line 1")
        expect(result).to include("Line 2")
      end

      it 'handles mixed spaces and tabs' do
        content = "Line 1  \t\nLine 2"
        result = transformer.transform(content, normalize_whitespace: true)

        expect(result).to include("Line 1")
        expect(result).to include("Line 2")
      end

      it 'preserves indentation within lines' do
        content = "  Indented line\n    More indented"
        result = transformer.transform(content, normalize_whitespace: true)

        expect(result).to eq("Indented line\n    More indented")
      end

      it 'handles complex document with multiple issues' do
        content = <<~MD


          # Title

          ## Section 1


          Content here.



          ## Section 2

          More content.


        MD

        result = transformer.transform(content, normalize_whitespace: true)

        expect(result).not_to start_with("\n")
        expect(result).not_to end_with("  \n")
        expect(result).not_to include("\n\n\n\n")
        expect(result).to include("# Title\n")
        expect(result).to include("## Section 1\n")
      end

      it 'handles empty document' do
        content = ''
        result = transformer.transform(content, normalize_whitespace: true)

        expect(result).to eq('')
      end

      it 'handles document with only whitespace' do
        content = "   \n\n  \n\n\n  "
        result = transformer.transform(content, normalize_whitespace: true)

        expect(result).to eq('')
      end
    end

    context 'without normalize_whitespace option' do
      it 'returns content unchanged' do
        content = "Line 1   \n\n\n\n\nLine 2  "
        result = transformer.transform(content)

        expect(result).to eq(content)
      end
    end

    context 'with normalize_whitespace: false' do
      it 'returns content unchanged' do
        content = "Line 1   \n\n\n\n\nLine 2  "
        result = transformer.transform(content, normalize_whitespace: false)

        expect(result).to eq(content)
      end
    end
  end
end
