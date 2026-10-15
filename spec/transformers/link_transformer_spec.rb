# frozen_string_literal: true

RSpec.describe LlmDocsBuilder::Transformers::LinkTransformer do
  subject(:transformer) { described_class.new }

  describe '#transform' do
    let(:content) do
      <<~MD
        # Documentation

        Check out [the guide](./guide.md) for more info.
        Visit [our website](https://example.com/page.html).
        See [Click here to read the API docs](./api.md).
      MD
    end

    context 'with base_url option' do
      it 'expands relative links to absolute URLs' do
        result = transformer.transform(content, base_url: 'https://example.com')

        expect(result).to include('[the guide](https://example.com/guide.md)')
        expect(result).not_to include('[the guide](./guide.md)')
      end

      it 'preserves absolute URLs' do
        result = transformer.transform(content, base_url: 'https://example.com')

        expect(result).to include('[our website](https://example.com/page.html)')
      end

      it 'preserves anchor links' do
        content = '[Jump to section](#section)'
        result = transformer.transform(content, base_url: 'https://example.com')

        expect(result).to eq('[Jump to section](#section)')
      end

      it 'handles links starting with //' do
        content = '[Protocol-relative](//cdn.example.com/file.js)'
        result = transformer.transform(content, base_url: 'https://example.com')

        expect(result).to eq('[Protocol-relative](//cdn.example.com/file.js)')
      end

      it 'preserves mailto: links' do
        content = 'Contact [support](mailto:help@example.com)'
        result = transformer.transform(content, base_url: 'https://example.com/docs')

        expect(result).to eq('Contact [support](mailto:help@example.com)')
      end

      it 'preserves tel: links' do
        content = 'Call [us](tel:+1234567890)'
        result = transformer.transform(content, base_url: 'https://example.com/docs')

        expect(result).to eq('Call [us](tel:+1234567890)')
      end

      it 'preserves ftp: links' do
        content = 'Download [file](ftp://example.com/file.zip)'
        result = transformer.transform(content, base_url: 'https://example.com/docs')

        expect(result).to eq('Download [file](ftp://example.com/file.zip)')
      end

      it 'still expands relative links when non-http schemes are present' do
        content = 'See [guide](./guide.md) or [mail](mailto:a@b.com)'
        result = transformer.transform(content, base_url: 'https://example.com/docs')

        expect(result).to eq('See [guide](https://example.com/docs/guide.md) or [mail](mailto:a@b.com)')
      end

      it 'resolves parent directory links' do
        content = '[Other](../other.md)'
        result = transformer.transform(content, base_url: 'https://example.com/docs/v2')

        expect(result).to eq('[Other](https://example.com/docs/other.md)')
      end

      it 'resolves links without a ./ prefix' do
        content = '[Setup](guides/setup.md)'
        result = transformer.transform(content, base_url: 'https://example.com/docs/')

        expect(result).to eq('[Setup](https://example.com/docs/guides/setup.md)')
      end

      it 'resolves root-relative links from the base URL' do
        content = '[Root](/api/index.md)'
        result = transformer.transform(content, base_url: 'https://example.com/docs', source_path: 'guides/intro.md')

        expect(result).to eq('[Root](https://example.com/docs/api/index.md)')
      end

      it 'keeps anchors and query strings on relative links' do
        content = '[Config](../config.md?v=2#options)'
        result = transformer.transform(content, base_url: 'https://example.com', source_path: 'guides/intro.md')

        expect(result).to eq('[Config](https://example.com/config.md?v=2#options)')
      end

      it 'falls back to joining paths when the target is not a valid URI' do
        content = '[Spaced](./my page.md)'
        result = transformer.transform(content, base_url: 'https://example.com')

        expect(result).to eq('[Spaced](https://example.com/my page.md)')
      end
    end

    context 'with base_url and source_path options' do
      it 'resolves ./ links from the source file directory' do
        content = '[Setup](./setup.md)'
        result = transformer.transform(content, base_url: 'https://example.com', source_path: 'guides/intro.md')

        expect(result).to eq('[Setup](https://example.com/guides/setup.md)')
      end

      it 'resolves ../ links from the source file directory' do
        content = '[Guide](../../guides/getting-started.md)'
        result = transformer.transform(content,
          base_url: 'https://example.com/docs',
          source_path: 'docs/api/endpoints.md')

        expect(result).to eq('[Guide](https://example.com/docs/guides/getting-started.md)')
      end

      it 'resolves image paths from the source file directory' do
        content = '![Diagram](../images/flow.png)'
        result = transformer.transform(content, base_url: 'https://example.com', source_path: 'guides/intro.md')

        expect(result).to eq('![Diagram](https://example.com/images/flow.png)')
      end

      it 'leaves absolute URLs and anchors unchanged' do
        content = '[Site](https://other.com/a.md) [Top](#top) [Mail](mailto:a@b.com)'
        result = transformer.transform(content, base_url: 'https://example.com', source_path: 'guides/intro.md')

        expect(result).to eq(content)
      end
    end

    context 'with convert_urls option' do
      it 'converts .html URLs to .md' do
        result = transformer.transform(content, convert_urls: true)

        expect(result).to include('https://example.com/page.md')
        expect(result).not_to include('https://example.com/page.html')
      end

      it 'converts .htm URLs to .md' do
        content = 'Visit https://example.com/page.htm for details'
        result = transformer.transform(content, convert_urls: true)

        expect(result).to include('https://example.com/page.md')
        expect(result).not_to include('https://example.com/page.htm')
      end

      it 'preserves non-html URLs' do
        content = 'Download https://example.com/file.pdf'
        result = transformer.transform(content, convert_urls: true)

        expect(result).to include('https://example.com/file.pdf')
      end
    end

    context 'with simplify_links option' do
      it 'removes "click here to" prefix and "docs" suffix' do
        content = '[Click here to see the docs](./docs.md)'
        result = transformer.transform(content, simplify_links: true)

        expect(result).to eq('[see the](./docs.md)')
      end

      it 'removes "see" prefix' do
        content = '[See the guide](./guide.md)'
        result = transformer.transform(content, simplify_links: true)

        expect(result).to eq('[guide](./guide.md)')
      end

      it 'removes "see the" prefix' do
        content = '[See the complete guide](./guide.md)'
        result = transformer.transform(content, simplify_links: true)

        expect(result).to eq('[complete guide](./guide.md)')
      end

      it 'removes "read more about" prefix' do
        content = '[Read more about configuration](./config.md)'
        result = transformer.transform(content, simplify_links: true)

        expect(result).to eq('[configuration](./config.md)')
      end

      it 'removes "check out" prefix' do
        content = '[Check out the tutorial](./tutorial.md)'
        result = transformer.transform(content, simplify_links: true)

        expect(result).to eq('[tutorial](./tutorial.md)')
      end

      it 'removes "visit" prefix' do
        content = '[Visit the homepage](./index.md)'
        result = transformer.transform(content, simplify_links: true)

        expect(result).to eq('[homepage](./index.md)')
      end

      it 'removes "here" suffix' do
        content = '[Documentation here](./docs.md)'
        result = transformer.transform(content, simplify_links: true)

        expect(result).to eq('[Documentation](./docs.md)')
      end

      it 'removes "documentation" suffix' do
        content = '[API documentation](./api.md)'
        result = transformer.transform(content, simplify_links: true)

        expect(result).to eq('[API](./api.md)')
      end

      it 'removes "docs" suffix' do
        content = '[API docs](./api.md)'
        result = transformer.transform(content, simplify_links: true)

        expect(result).to eq('[API](./api.md)')
      end

      it 'handles case-insensitive matching' do
        content = '[CLICK HERE TO READ ABOUT API](./guide.md)'
        result = transformer.transform(content, simplify_links: true)

        expect(result).to include('API')
        expect(result).not_to include('CLICK HERE')
      end

      it 'preserves original text if simplification results in empty string' do
        content = '[here](./page.md)'
        result = transformer.transform(content, simplify_links: true)

        expect(result).to eq('[here](./page.md)')
      end

      it 'handles multiple transformations in one link' do
        content = '[Click here to complete guide material here](./guide.md)'
        result = transformer.transform(content, simplify_links: true)

        expect(result).to eq('[complete guide material](./guide.md)')
      end
    end

    context 'with multiple options combined' do
      it 'applies all transformations in order' do
        content = '[Click here to read more](./page.html)'
        result = transformer.transform(content,
          base_url: 'https://example.com',
          convert_urls: true,
          simplify_links: true)

        expect(result).to eq('[read more](https://example.com/page.md)')
      end
    end

    context 'with no options' do
      it 'returns content unchanged' do
        result = transformer.transform(content)

        expect(result).to eq(content)
      end
    end
  end
end
