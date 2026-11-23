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
        expect(result).to include('Text after.')
      end

      it 'keeps nested list items and the content after them' do
        content = <<~MD
          - Topics
              - Consumers
              - Producers

          ## Next section

          Important text.
        MD

        result = transformer.transform(content, remove_code_examples: true)

        expect(result).to eq(content)
      end

      it 'keeps an indented line inside a numbered list and the content after it' do
        content = <<~MD
          1. Install the gem:

              gem install karafka

          2. Configure it.

          ## Usage

          Text after.
        MD

        result = transformer.transform(content, remove_code_examples: true)

        expect(result).to eq(content)
      end

      it 'removes only the indented code block, not the rest of the document' do
        content = "Intro.\n\n    code line\n\n- Item\n    continuation\n\nText after."
        result = transformer.transform(content, remove_code_examples: true)

        expect(result).to eq("Intro.\n\n\n\n- Item\n    continuation\n\nText after.")
      end

      it 'removes indented code after a heading that ends a list' do
        content = "- a\n## H\n\n    code\n\nAfter.\n"
        result = transformer.transform(content, remove_code_examples: true)

        expect(result).to eq("- a\n## H\n\n\n\nAfter.\n")
      end

      it 'keeps an indented line after a hash tag line in a list item' do
        content = "- a\n#tag\n\n    para in item\n\nAfter.\n"
        result = transformer.transform(content, remove_code_examples: true)

        expect(result).to eq(content)
      end

      it 'removes indented code after a fenced block that ends a list' do
        content = "- a\n\n```\nx\n```\n\n    code\n\nAfter.\n"
        result = transformer.transform(content, remove_code_examples: true)

        expect(result).to eq("- a\n\n\n\n\n\nAfter.\n")
      end

      it 'removes indented code after a fenced block right after a list item' do
        content = "- a\n```\nx\n```\n\n    code\n\nAfter.\n"
        result = transformer.transform(content, remove_code_examples: true)

        expect(result).to eq("- a\n\n\n\n\nAfter.\n")
      end

      it 'keeps a shorter fence inside a fenced block as code' do
        content = "```\nx\n``\ny\n```\nAfter.\n"
        result = transformer.transform(content, remove_code_examples: true)

        expect(result).to eq("\nAfter.\n")
      end

      it 'closes a fenced block with a longer fence' do
        content = "```\nx\n````\nAfter.\n"
        result = transformer.transform(content, remove_code_examples: true)

        expect(result).to eq("\nAfter.\n")
      end

      it 'removes a fenced block in a blockquote indented by spaces' do
        content = " > ```\n > x\n > ```\n\nAfter.\n"
        result = transformer.transform(content, remove_code_examples: true)

        expect(result).to eq("\n\nAfter.\n")
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

    context 'with code in the content' do
      {
        remove_comments: ['<!-- keep -->', '<!-- drop -->'],
        remove_badges: ['[![CI](badge.svg)](https://ci.com)', '[![CI](https://img.shields.io/x.svg)](https://ci.com)'],
        remove_images: ['![Diagram](diagram.png)', '![Logo](logo.png)'],
        remove_blockquotes: ['> Note: quoted', '> Outside quote']
      }.each do |option, (inside, outside)|
        context "with #{option} option" do
          it 'keeps the element inside fenced code and removes it outside' do
            code = "```markdown\n#{inside}\n```\n"
            content = "#{outside}\n\n#{code}"

            result = transformer.transform(content, option => true)

            expect(result).to end_with("\n\n#{code}")
            expect(result).not_to include(outside)
          end

          it 'keeps the element inside indented code and removes it outside' do
            code = "    #{inside}\n"
            content = "#{outside}\n\n#{code}"

            result = transformer.transform(content, option => true)

            expect(result).to end_with("\n\n#{code}")
            expect(result).not_to include(outside)
          end

          it 'keeps the element inside inline code' do
            content = "Use `#{inside}` here.\n"

            result = transformer.transform(content, option => true)

            expect(result).to eq(content)
          end
        end
      end

      %i[remove_images remove_badges].each do |option|
        it "does not let #{option} remove code after an unclosed image destination" do
          content = "![a](badge.svg\n\n```\ncode\n```\n\nSee [b](x.svg).\n"

          result = transformer.transform(content, option => true)

          expect(result).to eq(content)
        end
      end

      it 'does not let a linked badge remove code after an unclosed part' do
        content = <<~MD
          [![a](badge

          ```
          first
          ```

          [![b](c.svg)](d)

          [![e](f.svg)](g

          ```
          second
          ```

          See (h).
        MD

        result = transformer.transform(content, remove_badges: true)

        expect(result).to include("```\nfirst\n```", "```\nsecond\n```")
        expect(result).not_to include('[![b]')
      end

      it 'does not end a comment at a closing marker inside code' do
        content = "```html\n<!-- open\n```\n\nText.\n\n```html\nclose -->\n```\n"

        result = transformer.transform(content, remove_comments: true)

        expect(result).to eq(content)
      end

      it 'removes a comment around a code block with the code' do
        content = "<!--\n```\ncode\n```\n-->\nText.\n"

        result = transformer.transform(content, remove_comments: true)

        expect(result).to eq("\nText.\n")
      end

      it 'removes one quote level from code inside a blockquote' do
        content = "> Note:\n>\n> ```markdown\n> > quoted\n> <!-- keep -->\n>\n> ```\n"

        result = transformer.transform(content, remove_blockquotes: true, remove_comments: true)

        expect(result).to eq("Note:\n```markdown\n> quoted\n<!-- keep -->\n\n```\n")
      end
    end

    context 'with a block' do
      let(:content) { "<!-- c -->\n[a](a.md)\n\n```\n<!-- kept --> [b](b.md)\n```\n" }

      it 'runs the block on cleaned content with code hidden and restores the code' do
        seen = nil

        result = transformer.transform(content, remove_comments: true) do |text|
          seen = text
          text.sub('a.md', 'x.md')
        end

        expect(seen).not_to include('<!--', 'b.md')
        expect(result).to eq("\n[a](x.md)\n\n```\n<!-- kept --> [b](b.md)\n```\n")
      end

      it 'runs the block when no removal applies' do
        result = transformer.transform(content) { |text| text.sub('a.md', 'x.md') }

        expect(result).to eq(content.sub('a.md', 'x.md'))
      end

      it 'runs the block after code examples are removed' do
        result = transformer.transform(content, remove_code_examples: true) { |text| "#{text}end\n" }

        expect(result).to eq("<!-- c -->\n[a](a.md)\n\n\nend\n")
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
