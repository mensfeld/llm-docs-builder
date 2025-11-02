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

      expect(markdown).to include('Inline code like ``puts `foo``` works too.')
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

    it 'preserves block-level descendants within list items' do
      html = <<~HTML
        <ul>
          <li>
            <p>Intro</p>
            <pre><code>puts "hi"</code></pre>
            <blockquote><p>Note</p></blockquote>
          </li>
        </ul>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        - Intro

          ```
          puts "hi"
          ```

          > Note
      MARKDOWN
    end

    it 'preserves manual line breaks created with <br>' do
      html = '<p>Line 1<br>Line 2<br><br>Line 4</p>'

      markdown = converter.convert(html)

      expect(markdown).to eq("Line 1\nLine 2\n\nLine 4")
    end

    it 'renders definition lists with a newline between terms and definitions' do
      html = '<dl><dt>Term</dt><dd>Definition</dd></dl>'

      markdown = converter.convert(html)

      expect(markdown).to eq("Term\n: Definition")
    end

    it 'preserves manual line breaks inside inline emphasis' do
      html = '<p><strong>Line 1<br>Line 2</strong></p>'

      markdown = converter.convert(html)

      expect(markdown).to eq("**Line 1\nLine 2**")
    end

    it 'preserves escaped angle brackets while decoding ampersands' do
      html = '<p>Use &lt;script&gt; &amp; friends.</p>'

      markdown = converter.convert(html)

      expect(markdown).to eq('Use &lt;script&gt; & friends.')
    end

    it 'escapes markdown special characters in link text' do
      html = '<p><a href="https://example.com">C++ [beta]_release</a></p>'

      markdown = converter.convert(html)

      expect(markdown).to eq('[C++ \\[beta\\]\\_release](https://example.com)')
    end

    it 'preserves markdown emitted by child nodes inside link text' do
      html = '<p><a href="https://example.com"><strong>Bold</strong></a></p>'

      markdown = converter.convert(html)

      expect(markdown).to eq('[**Bold**](https://example.com)')
    end

    it 'preserves nested images inside link text' do
      html = '<p><a href="https://example.com"><img src="/badge.svg" alt="Build status" /></a></p>'

      markdown = converter.convert(html)

      expect(markdown).to eq('[![Build status](/badge.svg)](https://example.com)')
    end

    it 'escapes markdown special characters in image alt text' do
      html = '<p><img src="/graph.png" alt="[beta] chart_*" /></p>'

      markdown = converter.convert(html)

      expect(markdown).to eq('![\\[beta\\] chart\\_\\*](/graph.png)')
    end

    it 'preserves inline nodes that are implicitly closed by ancestor tags' do
      html = '<p><strong>Bold</p>'

      markdown = converter.convert(html)

      expect(markdown).to eq('**Bold**')
    end

    it 'adds a blank line between lists and following paragraphs' do
      html = '<ul><li>Item</li></ul><p>Next</p>'

      markdown = converter.convert(html)

      expect(markdown).to eq("- Item\n\nNext")
    end

    it 'adds a blank line between adjacent block containers with inline content' do
      html = '<div>First</div><div>Second</div>'

      markdown = converter.convert(html)

      expect(markdown).to eq("First\n\nSecond")
    end

    it 'preserves text siblings mixed with inline elements inside block containers' do
      html = '<div>Hello <strong>World</strong></div>'

      markdown = converter.convert(html)

      expect(markdown).to eq('Hello **World**')
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

    it 'preserves spaces between inline elements separated by newline-only text nodes' do
      html = "<p><span>Hello</span>\n<span>world</span></p>"

      markdown = converter.convert(html)

      expect(markdown).to eq('Hello world')
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

    it 'renders inline-only blockquote content' do
      html = '<blockquote>Note</blockquote>'

      markdown = converter.convert(html)

      expect(markdown).to eq('> Note')
    end

    it 'renders inline sequence inside blockquote' do
      html = '<blockquote>Note <em>this</em> thing</blockquote>'

      markdown = converter.convert(html)

      expect(markdown).to eq('> Note *this* thing')
    end

    it 'preserves indentation within code fences inside blockquotes' do
      html = <<~HTML
        <blockquote>
          <pre><code>line1
      HTML
      html = html.dup
      html << "    line2</code></pre>\n"
      html << '        </blockquote>'

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        > ```
        > line1
        >     line2
        > ```
      MARKDOWN
    end

    it 'preserves block-level structure for div containers' do
      html = '<div><p>A</p><p>B</p></div>'

      markdown = converter.convert(html)

      expect(markdown).to eq("A\n\nB")
    end

    it 'preserves table markup without collapsing structure' do
      html = '<p>Before</p><table><tr><th>Plan</th><th>Status</th></tr><tr><td>Starter</td><td>Active</td></tr></table><p>After</p>'

      markdown = converter.convert(html)

      expect(markdown).to eq("Before\n\n<table><tr><th>Plan</th><th>Status</th></tr><tr><td>Starter</td><td>Active</td></tr></table>\n\nAfter")
    end

    it 'keeps table descendants in HTML so inline formatting continues to render' do
      html = <<~HTML
        <table>
          <tr>
            <td><a href="https://example.com"><strong>Details</strong></a></td>
          </tr>
        </table>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to include('<td><a href="https://example.com"><strong>Details</strong></a></td>')
      expect(markdown).not_to include('[Details](https://example.com)')
    end

    it 'renders pre/code blocks without inline backticks' do
      html = "<pre><code>puts 'hi'</code></pre>"

      markdown = converter.convert(html)

      expect(markdown).to eq("```\nputs 'hi'\n```")
    end

    it 'preserves intentional blank lines inside fenced code blocks' do
      html = "<pre><code>line1\n\n\nline2</code></pre>"

      markdown = converter.convert(html)

      expect(markdown).to eq("```\nline1\n\n\nline2\n```")
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

    it 'allows ordered lists to start at zero and preserves zero value overrides' do
      html = <<~HTML
        <ol start="0">
          <li>Zero</li>
          <li>One</li>
          <li value="0">Reset to zero</li>
          <li>Back to one</li>
        </ol>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to include('0. Zero')
      expect(markdown).to include('1. One')
      expect(markdown).to include('0. Reset to zero')
      expect(markdown).to include('1. Back to one')
    end

    it 'drops whitespace-only nodes between block elements' do
      html = '<h1>Title</h1> <p>Text</p>'

      markdown = converter.convert(html)

      expect(markdown).to eq("# Title\n\nText")
    end

    it 'handles paragraphs with only whitespace' do
      html = "<p>   \n\t  </p>"

      markdown = converter.convert(html)

      # Whitespace-only paragraphs render empty output
      expect(markdown).to eq('')
    end

    it 'handles figure elements as block containers' do
      html = <<~HTML
        <figure>
          <img src="/image.png" alt="Figure image" />
          <figcaption>Caption text</figcaption>
        </figure>
      HTML

      markdown = converter.convert(html)

      # Figure renders image and caption as separate blocks
      expect(markdown).to eq("![Figure image](/image.png)\n\nCaption text")
    end

    it 'handles blockquote with only whitespace' do
      html = "<blockquote>   \n\t  </blockquote>"

      markdown = converter.convert(html)

      # Whitespace-only blockquote renders empty output
      expect(markdown).to eq('')
    end
  end
end
