# frozen_string_literal: true

RSpec.describe LlmDocsBuilder::Transformers::ContentCleanupTransformer do
  subject(:transformer) { described_class.new }

  describe '#transform' do
    context 'with remove_frontmatter option' do
      it 'removes YAML frontmatter' do
        content = <<~MD
          ---
          layout: post
          title: Test
          ---

          # Content
        MD

        result = transformer.transform(content, remove_frontmatter: true)

        expect(result).not_to include('layout: post')
        expect(result).to include('# Content')
      end

      it 'removes TOML frontmatter' do
        content = <<~MD
          +++
          layout = "post"
          title = "Test"
          +++

          # Content
        MD

        result = transformer.transform(content, remove_frontmatter: true)

        expect(result).not_to include('layout = "post"')
        expect(result).to include('# Content')
      end

      it 'preserves content without frontmatter' do
        content = "# No Frontmatter\n\nJust content."
        result = transformer.transform(content, remove_frontmatter: true)

        expect(result).to eq(content)
      end
    end

    context 'with remove_comments option' do
      it 'removes HTML comments' do
        content = <<~MD
          # Title

          <!-- This is a comment -->

          Some content.
        MD

        result = transformer.transform(content, remove_comments: true)

        expect(result).not_to include('<!-- This is a comment -->')
        expect(result).to include('# Title')
        expect(result).to include('Some content.')
      end

      it 'removes multi-line HTML comments' do
        content = <<~MD
          # Title

          <!--
            This is a multi-line
            comment
          -->

          Content.
        MD

        result = transformer.transform(content, remove_comments: true)

        expect(result).not_to include('This is a multi-line')
        expect(result).to include('Content.')
      end
    end

    context 'with remove_badges option' do
      it 'removes badge images' do
        content = '[![Build Status](https://img.shields.io/badge.svg)](https://ci.com)'
        result = transformer.transform(content, remove_badges: true)

        expect(result).not_to include('[![Build Status]')
      end

      it 'removes various badge patterns' do
        content = <<~MD
          [![CI](badge.svg)](https://ci.com)
          [![Version](https://badge.io/v.svg)](https://pkg.com)
          [![License](badge.png)](https://license.com)
        MD

        result = transformer.transform(content, remove_badges: true)

        expect(result).not_to include('[![CI]')
        expect(result).not_to include('[![Version]')
        expect(result).not_to include('[![License]')
      end

      it 'preserves non-badge images' do
        content = '![Diagram](./diagram.png)'
        result = transformer.transform(content, remove_badges: true)

        expect(result).to include('![Diagram](./diagram.png)')
      end
    end

    context 'with remove_code_examples option' do
      it 'removes fenced code blocks' do
        content = <<~MD
          # Code

          ```ruby
          def hello
            puts "world"
          end
          ```

          Text after.
        MD

        result = transformer.transform(content, remove_code_examples: true)

        expect(result).not_to include('def hello')
        expect(result).not_to include('```ruby')
        expect(result).to include('# Code')
        expect(result).to include('Text after.')
      end

      it 'removes indented code blocks' do
        content = "# Code\n\n    def hello\n      puts \"world\"\n    end\n\nText after."
        result = transformer.transform(content, remove_code_examples: true)

        expect(result).not_to include('def hello')
        expect(result).to include('# Code')
      end

      it 'removes inline code' do
        content = 'Use the `puts` method to output text.'
        result = transformer.transform(content, remove_code_examples: true)

        expect(result).to eq('Use the  method to output text.')
      end

      it 'removes all code types together' do
        content = "# Examples\n\n```ruby\nputs \"hello\"\n```\n\nUse `method` here.\n\n    indented\n\nDone."
        result = transformer.transform(content, remove_code_examples: true)

        expect(result).not_to include('```ruby')
        expect(result).not_to include('puts "hello"')
        expect(result).not_to include('`method`')
        expect(result).to include('# Examples')
      end
    end

    context 'with remove_images option' do
      it 'removes image syntax' do
        content = '![Diagram](./diagram.png)'
        result = transformer.transform(content, remove_images: true)

        expect(result).not_to include('![Diagram]')
      end

      it 'removes images with various URLs' do
        content = <<~MD
          ![Local](./image.png)
          ![Remote](https://example.com/image.jpg)
          ![Relative](../images/pic.gif)
        MD

        result = transformer.transform(content, remove_images: true)

        expect(result).not_to include('![Local]')
        expect(result).not_to include('![Remote]')
        expect(result).not_to include('![Relative]')
      end

      it 'preserves non-image links' do
        content = '[Link](./page.md)'
        result = transformer.transform(content, remove_images: true)

        expect(result).to include('[Link](./page.md)')
      end
    end

    context 'with remove_blockquotes option' do
      it 'removes blockquote formatting' do
        content = <<~MD
          # Title

          > This is a blockquote
          > with multiple lines

          Regular text.
        MD

        result = transformer.transform(content, remove_blockquotes: true)

        expect(result).not_to match(/^>\s/)
        expect(result).to include('This is a blockquote')
        expect(result).to include('with multiple lines')
        expect(result).to include('Regular text.')
      end

      it 'handles nested blockquotes' do
        content = "> Level 1\n> Level 2"
        result = transformer.transform(content, remove_blockquotes: true)

        expect(result).not_to match(/^>\s/)
        expect(result).to include('Level')
      end

      it 'preserves content without blockquotes' do
        content = "# Title\n\nNormal content."
        result = transformer.transform(content, remove_blockquotes: true)

        expect(result).to eq(content)
      end
    end

    context 'with multiple options combined' do
      it 'applies all cleanup operations' do
        content = <<~MD
          ---
          layout: post
          ---

          # Title

          <!-- Comment -->

          [![Badge](badge.svg)](https://ci.com)

          > Blockquote text

          ```ruby
          code here
          ```

          ![Image](./pic.png)

          Final text.
        MD

        result = transformer.transform(content,
          remove_frontmatter: true,
          remove_comments: true,
          remove_badges: true,
          remove_code_examples: true,
          remove_images: true,
          remove_blockquotes: true)

        expect(result).not_to include('layout: post')
        expect(result).not_to include('<!-- Comment -->')
        expect(result).not_to include('[![Badge]')
        expect(result).not_to include('code here')
        expect(result).not_to include('![Image]')
        expect(result).not_to match(/^>\s/)
        expect(result).to include('# Title')
        expect(result).to include('Blockquote text')
        expect(result).to include('Final text.')
      end
    end

    context 'with no options' do
      it 'returns content unchanged' do
        content = <<~MD
          ---
          layout: post
          ---

          # Title

          <!-- Comment -->

          Content.
        MD

        result = transformer.transform(content)

        expect(result).to eq(content)
      end
    end
  end
end
