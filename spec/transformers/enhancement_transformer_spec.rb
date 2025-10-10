# frozen_string_literal: true

RSpec.describe LlmDocsBuilder::Transformers::EnhancementTransformer do
  subject(:transformer) { described_class.new }

  describe '#transform' do
    context 'with generate_toc option' do
      it 'generates table of contents from headings' do
        content = <<~MD
          # Main Title

          ## Section 1

          ## Section 2

          ### Subsection 2.1
        MD

        result = transformer.transform(content, generate_toc: true)

        expect(result).to include('## Table of Contents')
        expect(result).to include('- [Section 1](#section-1)')
        expect(result).to include('- [Section 2](#section-2)')
        expect(result).to include('  - [Subsection 2.1](#subsection-21)')
      end

      it 'skips the first H1 heading in TOC' do
        content = <<~MD
          # Main Title

          ## Section 1
        MD

        result = transformer.transform(content, generate_toc: true)

        expect(result).not_to include('[Main Title]')
        expect(result).to include('[Section 1]')
      end

      it 'creates GitHub-style anchor links' do
        content = <<~MD
          # Title

          ## Getting Started Guide

          ## API Reference
        MD

        result = transformer.transform(content, generate_toc: true)

        expect(result).to include('[Getting Started Guide](#getting-started-guide)')
        expect(result).to include('[API Reference](#api-reference)')
      end

      it 'handles headings with special characters' do
        content = "# Title\n\n## Section with: Colons"
        result = transformer.transform(content, generate_toc: true)

        expect(result).to include('## Table of Contents')
        expect(result).to include('Section with: Colons')
      end

      it 'indents TOC entries based on heading level' do
        content = "# Title\n\n## Level 2\n\n### Level 3"
        result = transformer.transform(content, generate_toc: true)

        expect(result).to include('## Table of Contents')
        expect(result).to include('[Level 2]')
        expect(result).to include('[Level 3]')
      end

      it 'places TOC after first H1 heading' do
        content = <<~MD
          # Main Title

          Introduction text.

          ## Section 1
        MD

        result = transformer.transform(content, generate_toc: true)

        lines = result.lines
        h1_index = lines.index("# Main Title\n")
        toc_index = lines.index("## Table of Contents\n")

        expect(toc_index).to be > h1_index
        expect(toc_index).to be < lines.index("Introduction text.\n")
      end

      it 'handles content without H1 heading' do
        content = <<~MD
          ## Section 1

          ## Section 2
        MD

        result = transformer.transform(content, generate_toc: true)

        expect(result).to include('## Table of Contents')
        expect(result).to include('[Section 1]')
        expect(result).to include('[Section 2]')
      end

      it 'returns content unchanged if no headings found' do
        content = 'Just plain text with no headings.'
        result = transformer.transform(content, generate_toc: true)

        expect(result).to eq(content)
      end

      it 'adds horizontal rule separator after TOC' do
        content = <<~MD
          # Title

          ## Section 1
        MD

        result = transformer.transform(content, generate_toc: true)

        expect(result).to include("---\n")
      end
    end

    context 'with custom_instruction option' do
      it 'injects custom instruction at document top' do
        content = <<~MD
          # Title

          Content here.
        MD

        instruction = 'This is AI-optimized documentation'
        result = transformer.transform(content, custom_instruction: instruction)

        expect(result).to include('> **AI Context**: This is AI-optimized documentation')
      end

      it 'places instruction after first H1 heading' do
        content = <<~MD
          # Main Title

          Content here.
        MD

        instruction = 'AI context'
        result = transformer.transform(content, custom_instruction: instruction)

        lines = result.lines
        h1_index = lines.index("# Main Title\n")
        instruction_line = lines.find { |l| l.include?('AI Context') }

        expect(lines.index(instruction_line)).to be > h1_index
      end

      it 'uses blockquote format by default' do
        content = "# Title\n\nContent."
        instruction = 'AI context'
        result = transformer.transform(content, custom_instruction: instruction)

        expect(result).to include('> **AI Context**: AI context')
      end

      it 'uses plain format when remove_blockquotes is true' do
        content = "# Title\n\nContent."
        instruction = 'AI context'
        result = transformer.transform(content,
          custom_instruction: instruction,
          remove_blockquotes: true)

        expect(result).to include('**AI Context**: AI context')
        expect(result).not_to include('> **AI Context**')
      end

      it 'adds horizontal rule separator after instruction' do
        content = "# Title\n\nContent."
        instruction = 'AI context'
        result = transformer.transform(content, custom_instruction: instruction)

        expect(result).to include("---\n")
      end

      it 'handles content without H1 heading' do
        content = 'Content without heading.'
        instruction = 'AI context'
        result = transformer.transform(content, custom_instruction: instruction)

        expect(result).to start_with('> **AI Context**: AI context')
      end

      it 'ignores nil instruction' do
        content = "# Title\n\nContent."
        result = transformer.transform(content, custom_instruction: nil)

        expect(result).to eq(content)
      end

      it 'ignores empty instruction' do
        content = "# Title\n\nContent."
        result = transformer.transform(content, custom_instruction: '')

        expect(result).to eq(content)
      end
    end

    context 'with both generate_toc and custom_instruction' do
      it 'adds custom instruction before TOC' do
        content = "# Title\n\n## Section 1"
        instruction = 'AI-optimized'
        result = transformer.transform(content,
          custom_instruction: instruction,
          generate_toc: true)

        expect(result).to include('**AI Context**: AI-optimized')
        expect(result).to include('## Table of Contents')
      end

      it 'maintains proper spacing between elements' do
        content = <<~MD
          # Title

          ## Section 1
        MD

        result = transformer.transform(content,
          custom_instruction: 'AI context',
          generate_toc: true)

        expect(result).to include("---\n")
        expect(result.scan(/---/).length).to eq(2) # One after instruction, one after TOC
      end
    end

    context 'with no options' do
      it 'returns content unchanged' do
        content = <<~MD
          # Title

          ## Section 1

          Content here.
        MD

        result = transformer.transform(content)

        expect(result).to eq(content)
      end
    end
  end
end
