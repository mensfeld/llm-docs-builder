# frozen_string_literal: true

RSpec.describe LlmDocsBuilder::HtmlToMarkdownConverter do
  subject(:converter) { described_class.new }

  describe '#convert' do
    it 'converts common HTML elements into markdown' do
      html = <<~HTML
        <html>
          <body>
            <h1>Sample Title</h1>
            <p>The first paragraph with <strong>bold</strong> text and a <a href="https://example.com">link</a>.</p>
            <ol>
              <li>First item</li>
              <li>Second item</li>
            </ol>
            <p>Inline code like <code>puts 'hi'</code> works too.</p>
          </body>
        </html>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to include("# Sample Title\n")
      expect(markdown).to include('The first paragraph with **bold** text and a [link](https://example.com).')
      expect(markdown).to include('1. First item')
      expect(markdown).to include('2. Second item')
      expect(markdown).to include("Inline code like `puts 'hi'` works too.")
    end

    it "doesn't hang on raw '<' inside script content and returns empty string" do
      html = '<script>if (a < b) {}</script>'

      markdown = converter.convert(html)

      expect(markdown).to eq('')
    end

    it 'tokenizes tags with quoted attributes containing greater-than characters' do
      html = '<p><a href="https://example.com" title="1 > 2">Link</a></p>'

      markdown = converter.convert(html)

      expect(markdown).to eq('[Link](https://example.com)')
    end

    it 'uses longer fences for inline code containing backticks' do
      html = '<p>Inline code like <code>puts `foo`</code> works too.</p>'

      markdown = converter.convert(html)

      expect(markdown).to include('Inline code like `` puts `foo` `` works too.')
    end

    it 'returns empty string for blank input' do
      expect(converter.convert('')).to eq('')
    end

    it 'preserves nested list formatting' do
      html = <<~HTML
        <ul>
          <li>
            Parent
            <ul>
              <li>Child</li>
            </ul>
          </li>
        </ul>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to include("- Parent\n  - Child")
    end

    it 'indents all nested list items' do
      html = <<~HTML
        <ul>
          <li>
            Parent
            <ul>
              <li>Child 1</li>
              <li>Child 2</li>
              <li>Child 3</li>
            </ul>
          </li>
        </ul>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to include("- Parent\n  - Child 1\n  - Child 2\n  - Child 3")
    end

    it 'preserves manual line breaks created with <br>' do
      html = '<p>Line 1<br>Line 2<br><br>Line 4</p>'

      markdown = converter.convert(html)

      expect(markdown).to eq("Line 1\nLine 2\n\nLine 4")
    end

    it 'adds a blank line between lists and following paragraphs' do
      html = '<ul><li>Item</li></ul><p>Next</p>'

      markdown = converter.convert(html)

      expect(markdown).to eq("- Item\n\nNext")
    end

    it 'collapses formatting newlines inside paragraphs into spaces' do
      html = <<~HTML
        <p>This sentence
          continues on the next line.</p>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to eq('This sentence continues on the next line.')
    end

    it 'collapses inline paragraph newlines without indentation' do
      html = "<p>This sentence\ncontinues on the next line.</p>"

      markdown = converter.convert(html)

      expect(markdown).to eq('This sentence continues on the next line.')
    end

    it 'preserves paragraph breaks inside blockquotes' do
      html = <<~HTML
        <blockquote>
          <p>First paragraph</p>
          <p>Second paragraph</p>
        </blockquote>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to eq("> First paragraph\n>\n> Second paragraph")
    end

    it 'preserves block-level structure for div containers' do
      html = '<div><p>A</p><p>B</p></div>'

      markdown = converter.convert(html)

      expect(markdown).to eq("A\n\nB")
    end

    it 'renders pre/code blocks without inline backticks' do
      html = "<pre><code>puts 'hi'</code></pre>"

      markdown = converter.convert(html)

      expect(markdown).to eq("```\nputs 'hi'\n```")
    end

    it 'respects ordered list offsets and li value overrides' do
      html = <<~HTML
        <ol start="3">
          <li>Starts at three</li>
          <li value="7">Jumps to seven</li>
          <li>Then eight</li>
        </ol>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to include('3. Starts at three')
      expect(markdown).to include('7. Jumps to seven')
      expect(markdown).to include('8. Then eight')
    end

    it 'drops whitespace-only nodes between block elements' do
      html = '<h1>Title</h1> <p>Text</p>'

      markdown = converter.convert(html)

      expect(markdown).to eq("# Title\n\nText")
    end
  end
end
