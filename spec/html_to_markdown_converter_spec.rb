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

    it 'renders multiple definitions for a single term in definition lists' do
      html = '<dl><dt>API</dt><dd>v1</dd><dd>v2</dd></dl>'

      markdown = converter.convert(html)

      expect(markdown).to eq("API\n: v1\n: v2")
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

    it 'escapes raw text but preserves nested markdown inside link labels' do
      html = '<p><a href="https://example.com">Check [status] <strong>now</strong></a></p>'

      markdown = converter.convert(html)

      expect(markdown).to eq('[Check \\[status\\] **now**](https://example.com)')
    end

    it 'wraps link URLs containing parentheses in angle brackets' do
      html = '<p><a href="https://example.com/foo(bar)">Link</a></p>'

      markdown = converter.convert(html)

      expect(markdown).to eq('[Link](<https://example.com/foo(bar)>)')
    end

    it 'removes dangling separators when dropping unsafe links' do
      html = '<p>Foo | <a href="javascript:bad">Bad</a></p>'

      markdown = converter.convert(html)

      expect(markdown).to eq('Foo')
    end

    it 'escapes markdown special characters in image alt text' do
      html = '<p><img src="/graph.png" alt="[beta] chart_*" /></p>'

      markdown = converter.convert(html)

      expect(markdown).to eq('![\\[beta\\] chart\\_\\*](/graph.png)')
    end

    it 'wraps image URLs containing parentheses in angle brackets' do
      html = '<p><img src="https://example.com/foo(bar).png" alt="Pic" /></p>'

      markdown = converter.convert(html)

      expect(markdown).to eq('![Pic](<https://example.com/foo(bar).png>)')
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

    it 'convert table markup into markdown' do
      html = '<table><tr><th>Plan</th><th>Status</th></tr><tr><td>Starter</td><td>Active</td></tr></table>'

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        | Plan | Status |
        |------|--------|
        | Starter | Active |
      MARKDOWN
    end

    it 'renders table captions before the markdown table' do
      html = <<~HTML
        <table>
          <caption>Plan summary</caption>
          <tr>
            <th>Plan</th>
            <th>Status</th>
          </tr>
          <tr>
            <td>Starter</td>
            <td>Active</td>
          </tr>
        </table>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        Plan summary

        | Plan | Status |
        |------|--------|
        | Starter | Active |
      MARKDOWN
    end

    it 'promotes the first row to a header without duplicating it when thead is missing' do
      html = '<table><tr><td>A</td><td>B</td></tr><tr><td>C</td><td>D</td></tr></table>'

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        | A | B |
        |---|---|
        | C | D |
      MARKDOWN
    end

    it 'escapes pipe characters inside table cell content' do
      html = '<table><tr><th>Note</th></tr><tr><td>A | B</td></tr></table>'

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        | Note |
        |------|
        | A \\| B |
      MARKDOWN
    end

    it 'preserves line breaks in table cells without forcing <br> tags' do
      html = '<table><tr><th>Note</th></tr><tr><td>Line 1<br>Line 2</td></tr></table>'

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        | Note   |
        |--------|
        | Line 1 |
        | Line 2 |
      MARKDOWN
    end

    it 'renders list content inside table cells without flattening structure' do
      html = <<~HTML
        <table>
          <tr>
            <th>Items</th>
          </tr>
          <tr>
            <td>
              <ul>
                <li>First</li>
                <li>Second</li>
              </ul>
            </td>
          </tr>
        </table>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        | Items    |
        |----------|
        | - First  |
        | - Second |
      MARKDOWN
    end

    it 'will keep the raw code block inside a table cell' do
      html = <<~HTML
        <table>
          <tr>
            <th>Snippet</th>
          </tr>
          <tr>
            <td><pre><code>puts 'hi'</code></pre></td>
          </tr>
        </table>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        | Snippet   |
        |-----------|
        | ```       |
        | puts 'hi' |
        | ```       |
      MARKDOWN
    end

    it 'falls back to raw HTML when a table contains nested tables' do
      html = <<~HTML
        <table>#{'        '}
          <tr>
            <td>
              Outer cell
              <table>
                <tr>
                  <td>Inner cell</td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to include('<table>')
      expect(markdown).to include('<td>Inner cell</td>')
      expect(markdown).not_to include('| Outer cell |')
    end

    it 'preserves pipe characters inside inline code spans within table cells' do
      html = '<table><tr><th>Example</th></tr><tr><td><code>foo|bar</code></td></tr></table>'

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        | Example |
        |---------|
        | `foo|bar` |
      MARKDOWN
    end

    it 'retains pipe characters inside table cells without splitting columns' do
      html = '<table><tr><th>Pure example</th></tr><tr><td>foo | bar</td></tr></table>'

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        | Pure example |
        |--------------|
        | foo \\| bar |
      MARKDOWN
    end

    it 'preserves colspan attributes by retaining the original HTML table' do
      html = <<~HTML
        <table>
          <tr>
            <th>A</th>
            <th>B</th>
          </tr>
          <tr>
            <td colspan="2">Total row</td>
          </tr>
          <tr>
            <td>C</td>
            <td>D</td>
          </tr>
        </table>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        | A | B |
        |---|---|
        | Total row |
        | C | D |
      MARKDOWN
    end

    it 'escapes pipes inside colspan rows' do
      html = '<table><tr><th>H1</th><th>H2</th></tr><tr><td colspan="2">foo | bar</td></tr></table>'

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        | H1 | H2 |
        |----|----|
        | foo \\| bar |
      MARKDOWN
    end

    it 'preserves rowspan attributes by retaining the original HTML table' do
      html = '<table><tr><th>H1</th><th>H2</th></tr><tr><td rowspan="3">A</td><td>B</td></tr><tr><td>C</td></tr><tr><td>D</td></tr></table>'

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        | H1 | H2 |
        |----|----|
        | A | B |
        |  | C |
        |  | D |
      MARKDOWN
    end

    it 'escapes pipes inside rowspan rows' do
      html = '<table><tr><th>H1</th><th>H2</th></tr><tr><td rowspan="2">foo | bar</td><td>B</td></tr><tr><td>C</td></tr></table>'

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        | H1 | H2 |
        |----|----|
        | foo \\| bar | B |
        |  | C |
      MARKDOWN
    end

    it 'renders a separator row with the same column count for rowspan tables' do
      html = '<table><thead><tr><th>H1</th><th>H2</th></tr></thead><tbody><tr><td>A</td><td rowspan="2">B</td></tr><tr><td>C</td></tr></tbody></table>'

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        | H1 | H2 |
        |----|----|
        | A | B |
        | C |  |
      MARKDOWN
    end

    it 'expands multiline rowspan cells into complete rows' do
      html = <<~HTML
        <table>
          <tr>
            <th>Left</th>
            <th>Right</th>
          </tr>
          <tr>
            <td rowspan="2">
              <ul>
                <li>Item 1</li>
                <li>Item 2</li>
              </ul>
            </td>
            <td>Right 1</td>
          </tr>
          <tr>
            <td>
              <ul>
                <li>First</li>
                <li>Second</li>
              </ul>
            </td>
          </tr>
        </table>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        | Left | Right |
        |------|-------|
        | - Item 1 | Right 1 |
        | - Item 2 |  |
        |  | - First  |
        |  | - Second |
      MARKDOWN
    end

    it 'renders pre/code blocks without inline backticks' do
      html = "<pre><code>puts 'hi'</code></pre>"

      markdown = converter.convert(html)

      expect(markdown).to eq("```\nputs 'hi'\n```")
    end

    it 'lengthens fenced code blocks when content contains backticks' do
      html = "<pre><code>```\nputs 'hi'\n```</code></pre>"

      markdown = converter.convert(html)

      expect(markdown).to eq("````\n```\nputs 'hi'\n```\n````")
    end

    it 'preserves intentional blank lines inside fenced code blocks' do
      html = "<pre><code>line1\n\n\nline2</code></pre>"

      markdown = converter.convert(html)

      expect(markdown).to eq("```\nline1\n\n\nline2\n```")
    end

    it 'preserves intentional blank lines inside longer fenced code blocks' do
      html = "<pre><code>```\nline1\n\n\nline2\n```</code></pre>"

      markdown = converter.convert(html)

      expect(markdown).to eq("````\n```\nline1\n\n\nline2\n```\n````")
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

    it 'remove javascript links and keep the rest' do
      html = <<~HTML
           <p class="source-link">
           Source:#{' '}
            <a id="l_method-c-new_source" href="javascript:toggleSource('method-c-new_source')">show</a>
           |#{' '}
            <a class="github_url" target="_blank" href="https://github.com/rails/rails/blob/1cdd190a25e483b65f1f25bbd0f13a25d696b461/actioncable/lib/action_cable/remote_connections.rb#L34">on GitHub</a>
        </p>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to eq('Source: [on GitHub](https://github.com/rails/rails/blob/1cdd190a25e483b65f1f25bbd0f13a25d696b461/actioncable/lib/action_cable/remote_connections.rb#L34)')
    end

    it 'Special convert figure code into the markdown code' do
      html = <<~HTML
        <figure class="code">
          <figcaption>Gemfile</figcaption>
          <div class="highlight">
            <table>
              <tbody>
                <tr>
                  <td class="line-numbers" aria-hidden="true">
                    <pre>
                      <div data-line="1" class="line-number"></div>
                      <div data-line="2" class="line-number"></div>
                    </pre>
                  </td>
                  <td class="main diff">
                    <pre>
                      <div class="line"><span></span><span class="gd">- gem 'capistrano-yarn'</span></div>
                      <div class="line"><span class="gi">+ gem 'capistrano-pnpm'</span></div>
                    </pre>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </figure>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        ```diff Gemfile
        - gem 'capistrano-yarn'
        + gem 'capistrano-pnpm'
        ```
      MARKDOWN
    end

    it 'preserves additional figure content after rendering code blocks' do
      html = <<~HTML
        <figure class="code">
          <figcaption>example.rb</figcaption>
          <pre><code>puts "hi"</code></pre>
          <p><em>Note:</em> runs on Ruby.</p>
        </figure>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        ```example.rb
        puts "hi"
        ```

        *Note:* runs on Ruby.
      MARKDOWN
    end

    it 'preserves figure child order when text precedes the code block' do
      html = <<~HTML
        <figure class="code">
          <figcaption>example.rb</figcaption>
          <p>Intro text.</p>
          <div class="highlight">
            <pre><code>puts "hi"</code></pre>
          </div>
          <p>Outro text.</p>
        </figure>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        Intro text.

        ```example.rb
        puts "hi"
        ```

        Outro text.
      MARKDOWN
    end

    it 'lengthens fences for figure code containing backticks' do
      code = <<~CODE
        ```
        echo "hi"
        ```
      CODE

      html = <<~HTML
        <figure class="code">
          <pre><code>#{code}</code></pre>
        </figure>
      HTML

      markdown = converter.convert(html)

      expect(markdown).to eq(<<~MARKDOWN.chomp)
        ````
        ```
        echo "hi"
        ```
        ````
      MARKDOWN
    end
  end
end
