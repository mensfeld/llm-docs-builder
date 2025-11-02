# frozen_string_literal: true

RSpec.describe LlmDocsBuilder::MarkdownTransformer do
  describe '#transform' do
    it 'normalises remote HTML content into markdown before applying other transformers' do
      html = <<~HTML
        <!doctype html>
        <html>
          <body>
            <h2>Subscriptions</h2>
            <p>Latest updates on plans.</p>
            <ul>
              <li><a href="https://example.com/a">First</a></li>
              <li><a href="https://example.com/b">Second</a></li>
            </ul>
          </body>
        </html>
      HTML

      transformer = described_class.new(nil, content: html)
      result = transformer.transform

      expect(result).to include('## Subscriptions')
      expect(result).to include('Latest updates on plans.')
      expect(result).to include('- [First](https://example.com/a)')
    end

    it 'normalises HTML documents that include inline body text nodes' do
      html = <<~HTML
        <html>
          <body>
            Welcome to <strong>Docs</strong>
            <p>Intro paragraph</p>
          </body>
        </html>
      HTML

      transformer = described_class.new(nil, content: html)
      result = transformer.transform

      expect(result).to include('Welcome to **Docs**')
      expect(result).to include('Intro paragraph')
      expect(result).not_to include('<html>')
      expect(result).not_to include('<body>')
    end

    it 'normalises remote HTML content even when leading comments are present' do
      html = <<~HTML
        <!-- build info -->
        <!-- status: ready -->
        <!doctype html>
        <html>
          <body>
            <h2>Subscriptions</h2>
            <p>Latest updates on plans.</p>
            <ul>
              <li><a href="https://example.com/a">First</a></li>
              <li><a href="https://example.com/b">Second</a></li>
            </ul>
          </body>
        </html>
      HTML

      transformer = described_class.new(nil, content: html)
      result = transformer.transform

      expect(result).to include('## Subscriptions')
      expect(result).to include('Latest updates on plans.')
      expect(result).to include('- [First](https://example.com/a)')
    end

    it 'preserves table-heavy HTML fragments without converting them' do
      html = <<~HTML
        <table>
          <thead>
            <tr>
              <th>Plan</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Starter</td>
              <td>Active</td>
            </tr>
          </tbody>
        </table>
      HTML

      transformer = described_class.new(nil, content: html)
      result = transformer.transform

      expect(result).to include('<table>')
      expect(result).to include('<td>Starter</td>')
      expect(result).to include('<td>Active</td>')
    end

    it 'leaves inline HTML mentions in markdown untouched' do
      markdown = "Use <p> tags for paragraphs.\n"

      transformer = described_class.new(nil, content: markdown)
      result = transformer.transform

      expect(result).to include('Use <p> tags for paragraphs.')
    end

    it 'treats markdown documents with leading HTML inline blocks as markdown' do
      markdown = <<~MARKDOWN
        <p>Intro</p>
        # Heading
        Body
      MARKDOWN

      transformer = described_class.new(nil, content: markdown)
      result = transformer.transform

      expect(result).to include('<p>Intro</p>')
      expect(result).to include("# Heading\nBody")
    end

    it 'leaves markdown lists untouched when preceded by an HTML block' do
      markdown = <<~MARKDOWN
        <p>Intro</p>
        - Item 1
        - Item 2
      MARKDOWN

      transformer = described_class.new(nil, content: markdown)
      result = transformer.transform

      expect(result).to include('<p>Intro</p>')
      expect(result).to include("- Item 1\n- Item 2")
    end

    it 'preserves paragraphs that follow an HTML block in markdown content' do
      markdown = <<~MARKDOWN
        <p>Intro</p>

        This is paragraph one.

        Second paragraph.
      MARKDOWN

      transformer = described_class.new(nil, content: markdown)
      result = transformer.transform

      expect(result).to include('<p>Intro</p>')
      expect(result).to include("This is paragraph one.\n\nSecond paragraph.")
    end

    it 'normalises HTML fragments that begin with head metadata' do
      html = <<~HTML
        <head>
          <meta charset="utf-8">
          <title>Plans</title>
        </head>
        <body>
          <h1>Plans</h1>
          <p>Choose the option that fits best.</p>
        </body>
      HTML

      transformer = described_class.new(nil, content: html)
      result = transformer.transform

      expect(result).to include('# Plans')
      expect(result).to include('Choose the option that fits best.')
      expect(result).not_to include('<meta')
    end

    it 'normalises HTML fragments that begin with unordered lists' do
      html = <<~HTML
        <ul>
          <li>One</li>
          <li>Two</li>
        </ul>
      HTML

      transformer = described_class.new(nil, content: html)
      result = transformer.transform

      expect(result).to include('- One')
      expect(result).to include('- Two')
      expect(result).not_to include('<ul>')
    end
  end
end
