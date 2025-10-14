# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmDocsBuilder::Transformers::HeadingTransformer do
  subject(:transformer) { described_class.new }

  describe '#transform' do
    context 'when normalize_headings is false' do
      let(:options) { { normalize_headings: false } }

      it 'returns content unchanged' do
        content = <<~MD
          # Main Title
          ## Section One
          ### Subsection
        MD

        expect(transformer.transform(content, options)).to eq(content)
      end
    end

    context 'when normalize_headings is true' do
      let(:options) { { normalize_headings: true } }

      it 'adds hierarchical context to H2 and below' do
        content = <<~MD
          # Configuration
          ## Consumer Settings
          ### auto_offset_reset
        MD

        result = transformer.transform(content, options)

        expect(result).to include('# Configuration')
        expect(result).to include('## Configuration / Consumer Settings')
        expect(result).to include('### Configuration / Consumer Settings / auto_offset_reset')
      end

      it 'keeps H1 unchanged' do
        content = <<~MD
          # Main Title
          Some content here.
        MD

        result = transformer.transform(content, options)

        expect(result).to include('# Main Title')
        expect(result).to include('Some content here.')
      end

      it 'handles multiple H1 sections correctly' do
        content = <<~MD
          # First Section
          ## Subsection A

          # Second Section
          ## Subsection B
        MD

        result = transformer.transform(content, options)

        expect(result).to include('# First Section')
        expect(result).to include('## First Section / Subsection A')
        expect(result).to include('# Second Section')
        expect(result).to include('## Second Section / Subsection B')
      end

      it 'handles deep nesting correctly' do
        content = <<~MD
          # Top
          ## Level 2
          ### Level 3
          #### Level 4
          ##### Level 5
          ###### Level 6
        MD

        result = transformer.transform(content, options)

        expect(result).to include('# Top')
        expect(result).to include('## Top / Level 2')
        expect(result).to include('### Top / Level 2 / Level 3')
        expect(result).to include('#### Top / Level 2 / Level 3 / Level 4')
        expect(result).to include('##### Top / Level 2 / Level 3 / Level 4 / Level 5')
        expect(result).to include('###### Top / Level 2 / Level 3 / Level 4 / Level 5 / Level 6')
      end

      it 'handles headings jumping levels' do
        content = <<~MD
          # Main
          ## Second
          #### Fourth (skipped third)
        MD

        result = transformer.transform(content, options)

        expect(result).to include('# Main')
        expect(result).to include('## Main / Second')
        expect(result).to include('#### Main / Second / Fourth (skipped third)')
      end

      it 'handles custom separator' do
        custom_options = { normalize_headings: true, heading_separator: ' > ' }
        content = <<~MD
          # API
          ## Authentication
          ### Keys
        MD

        result = transformer.transform(content, custom_options)

        expect(result).to include('# API')
        expect(result).to include('## API > Authentication')
        expect(result).to include('### API > Authentication > Keys')
      end

      it 'preserves content between headings' do
        content = <<~MD
          # Title
          Some intro text.

          ## Section
          More text here.

          ### Subsection
          Final text.
        MD

        result = transformer.transform(content, options)

        expect(result).to include('Some intro text.')
        expect(result).to include('More text here.')
        expect(result).to include('Final text.')
      end

      it 'handles headings with special characters' do
        content = <<~MD
          # API Reference
          ## Authentication & Authorization
          ### Using API Keys (OAuth2)
        MD

        result = transformer.transform(content, options)

        expect(result).to include('# API Reference')
        expect(result).to include('## API Reference / Authentication & Authorization')
        expect(result).to include('### API Reference / Authentication & Authorization / Using API Keys (OAuth2)')
      end
    end

    context 'when content has no headings' do
      let(:options) { { normalize_headings: true } }

      it 'returns content unchanged' do
        content = <<~MD
          Just some regular text.
          No headings here.
        MD

        expect(transformer.transform(content, options)).to eq(content)
      end
    end
  end
end
