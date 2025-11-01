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

      expect(result).to include("## Subscriptions")
      expect(result).to include('Latest updates on plans.')
      expect(result).to include('- [First](https://example.com/a)')
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

      expect(result).to include("## Subscriptions")
      expect(result).to include('Latest updates on plans.')
      expect(result).to include('- [First](https://example.com/a)')
    end
  end
end
