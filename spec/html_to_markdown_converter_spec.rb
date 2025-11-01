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
      expect(markdown).to include("The first paragraph with **bold** text and a [link](https://example.com).")
      expect(markdown).to include("1. First item")
      expect(markdown).to include("2. Second item")
      expect(markdown).to include("Inline code like `puts 'hi'` works too.")
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

      expect(markdown).to include("3. Starts at three")
      expect(markdown).to include("7. Jumps to seven")
      expect(markdown).to include("8. Then eight")
    end
  end
end
