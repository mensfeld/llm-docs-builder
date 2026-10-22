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

      it 'preserves links with any URI scheme, in any case' do
        content = '[U](HTTPS://example.com/x) [x](Mailto:a@b.c) [s](sftp://host/x) [y](ssh://git@h/r) ' \
                  '[g](git://host/r) [z](irc://h/c) [w](urn:isbn:1) [d](data:text/plain,hi) ' \
                  '[j](javascript:void(0)) [p](<Sftp://host/a b>)'
        result = transformer.transform(content, base_url: 'https://example.com/docs', source_path: 'guides/a.md')

        expect(result).to eq(content)
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

      it 'keeps spaces in link targets' do
        content = '[Spaced](./my page.md)'
        result = transformer.transform(content, base_url: 'https://example.com')

        expect(result).to eq('[Spaced](https://example.com/my page.md)')
      end

      it 'keeps trailing slashes on directory links' do
        content = '[Guides](./guides/) [Up](..)'
        result = transformer.transform(content, base_url: 'https://example.com/docs')

        expect(result).to eq('[Guides](https://example.com/docs/guides/) [Up](https://example.com/)')
      end

      it 'expands links whose text holds nested brackets' do
        content = '[a [b] c](../intro.md) and [a [b [c]] d](x.md)'
        result = transformer.transform(content, base_url: 'https://example.com/docs', source_path: 'guides/page.md')

        expect(result).to eq(
          '[a [b] c](https://example.com/docs/intro.md) and [a [b [c]] d](https://example.com/docs/guides/x.md)'
        )
      end

      it 'expands both the linked image and its link' do
        content = '[![alt](../img/a.png)](../intro.md) [![b](b.svg "B")](https://ci.example.com)'
        result = transformer.transform(content, base_url: 'https://example.com/docs', source_path: 'guides/page.md')

        expect(result).to eq(
          '[![alt](https://example.com/docs/img/a.png)](https://example.com/docs/intro.md) ' \
          '[![b](https://example.com/docs/guides/b.svg "B")](https://ci.example.com)'
        )
      end

      it 'expands a linked image without alt text' do
        content = '[![](badge.svg)](https://ci.example.com) [![](i.png)](x.md)'
        result = transformer.transform(content, base_url: 'https://example.com/docs', source_path: 'guides/page.md')

        expect(result).to eq(
          '[![](https://example.com/docs/guides/badge.svg)](https://ci.example.com) ' \
          '[![](https://example.com/docs/guides/i.png)](https://example.com/docs/guides/x.md)'
        )
      end

      it 'expands only the link after an unmatched opening bracket' do
        content = '[a [b](x.md) and [c]](y.md)'
        result = transformer.transform(content, base_url: 'https://example.com')

        expect(result).to eq('[a [b](https://example.com/x.md) and [c]](y.md)')
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

      it 'resolves links with a title and keeps the title' do
        content = '[A](./setup.md "Setup guide") [B](../index.md \'Home\')'
        result = transformer.transform(content, base_url: 'https://example.com', source_path: 'guides/intro.md')

        expect(result).to eq('[A](https://example.com/guides/setup.md "Setup guide") [B](https://example.com/index.md \'Home\')')
      end

      it 'resolves targets with spaces from the source file directory' do
        content = '[Spaced](../my notes/page one.md)'
        result = transformer.transform(content, base_url: 'https://example.com', source_path: 'guides/intro.md')

        expect(result).to eq('[Spaced](https://example.com/my notes/page one.md)')
      end

      it 'resolves angle-bracket targets and percent-encodes their spaces' do
        content = '[spa](<../../my docs/a b.md>)'
        result = transformer.transform(
          content,
          base_url: 'https://myproject.io/docs/',
          source_path: 'guides/sub/page.md'
        )

        expect(result).to eq('[spa](https://myproject.io/docs/my%20docs/a%20b.md)')
      end

      it 'resolves angle-bracket targets with a title, anchor or leading slash' do
        content = '[A](<./set up.md> "Setup") [B](<../a b.md#part 1>) [C](</root dir/x.md>)'
        result = transformer.transform(content, base_url: 'https://example.com/docs', source_path: 'guides/intro.md')

        expect(result).to eq(
          '[A](https://example.com/docs/guides/set%20up.md "Setup") ' \
          '[B](https://example.com/docs/a%20b.md#part%201) ' \
          '[C](https://example.com/docs/root%20dir/x.md)'
        )
      end

      it 'leaves angle-bracket absolute URLs and anchors unchanged' do
        content = '[Site](<https://other.com/a b.md>) [Top](<#top>) [Mail](<mailto:a@b.com>)'
        result = transformer.transform(content, base_url: 'https://example.com', source_path: 'guides/intro.md')

        expect(result).to eq(content)
      end

      it 'resolves query-only targets to the source file itself' do
        content = '[q](?tab=2) [qa](?tab=2#part "Tab") [self](#self)'
        result = transformer.transform(
          content,
          base_url: 'https://myproject.io/docs/',
          source_path: 'guides/sub/page.md'
        )

        expect(result).to eq(
          '[q](https://myproject.io/docs/guides/sub/page.md?tab=2) ' \
          '[qa](https://myproject.io/docs/guides/sub/page.md?tab=2#part "Tab") ' \
          '[self](#self)'
        )
      end

      it 'percent-encodes the source file name of query-only targets' do
        content = '[q](?tab=2)'
        results = ['my page.md', 'c#.md', 'a(b).md'].map do |name|
          transformer.transform(content, base_url: 'https://myproject.io/docs/', source_path: "guides/#{name}")
        end

        expect(results).to eq(
          [
            '[q](https://myproject.io/docs/guides/my%20page.md?tab=2)',
            '[q](https://myproject.io/docs/guides/c%23.md?tab=2)',
            '[q](https://myproject.io/docs/guides/a%28b%29.md?tab=2)'
          ]
        )
      end

      it 'resolves non-ASCII targets from the source file directory' do
        content = '[PL](./zażółć.md)'
        result = transformer.transform(content, base_url: 'https://example.com/docs', source_path: 'guides/intro.md')

        expect(result).to eq('[PL](https://example.com/docs/guides/zażółć.md)')
      end

      it 'leaves absolute URLs and anchors unchanged' do
        content = '[Site](https://other.com/a.md) [Top](#top) [Mail](mailto:a@b.com)'
        result = transformer.transform(content, base_url: 'https://example.com', source_path: 'guides/intro.md')

        expect(result).to eq(content)
      end
    end

    context 'with link reference definitions' do
      let(:options) { { base_url: 'https://myproject.io/docs/', source_path: 'guides/sub/page.md' } }

      it 'resolves definitions from the source file directory and keeps their titles' do
        content = <<~MD
          See [text][r1] and [collapsed][].

          [r1]: ../intro.md "Intro"
          [collapsed]: ./sibling.md
          [Root]: /api/index.md 'API'
          [sp]: <../my docs/a b.md> (Spaced)
          [q]: ?tab=2#part
        MD
        result = transformer.transform(content, options)

        expect(result).to eq(<<~MD)
          See [text][r1] and [collapsed][].

          [r1]: https://myproject.io/docs/guides/intro.md "Intro"
          [collapsed]: https://myproject.io/docs/guides/sub/sibling.md
          [Root]: https://myproject.io/docs/api/index.md 'API'
          [sp]: https://myproject.io/docs/guides/my%20docs/a%20b.md (Spaced)
          [q]: https://myproject.io/docs/guides/sub/page.md?tab=2#part
        MD
      end

      it 'resolves indented definitions and definitions in blockquotes' do
        content = "   [a]: ../a.md\n\n> [b]: ./b.md\n"
        result = transformer.transform(content, options)

        expect(result).to eq(
          "   [a]: https://myproject.io/docs/guides/a.md\n\n> [b]: https://myproject.io/docs/guides/sub/b.md\n"
        )
      end

      it 'resolves definitions after a heading, a thematic break or a code block' do
        content = <<~MD
          ## References
          [a]: ../a.md

          ---
          [b]: ../b.md

          ```rb
          x = 1
          ```
          [c]: ../c.md

          `code`
          [para]: ../para.md
        MD
        result = transformer.transform(content, options)

        expect(result).to eq(<<~MD)
          ## References
          [a]: https://myproject.io/docs/guides/a.md

          ---
          [b]: https://myproject.io/docs/guides/b.md

          ```rb
          x = 1
          ```
          [c]: https://myproject.io/docs/guides/c.md

          `code`
          [para]: ../para.md
        MD
      end

      it 'resolves definitions after leading blank lines once' do
        options = { base_url: '/docs/', source_path: 'guides/page.md' }

        expect(transformer.transform("\n\n[a]: ../intro.md\n", options)).to eq("\n\n[a]: /docs/intro.md\n")
        expect(transformer.transform(">\n>\n> [a]: ../intro.md\n", options)).to eq(">\n>\n> [a]: /docs/intro.md\n")
      end

      it 'leaves definitions with a URI scheme, protocol-relative targets and anchors unchanged' do
        content = <<~MD
          [a]: https://other.com/a.md
          [b]: MAILTO:a@b.com
          [c]: sftp://host/x
          [d]: //cdn.example.com/x.js
          [e]: #top
          [f]: <https://other.com/a b.md>
        MD

        expect(transformer.transform(content, options)).to eq(content)
      end

      it 'leaves footnotes, definitions inside a paragraph and invalid definitions unchanged' do
        content = <<~MD
          [^1]: Footnote text.
          [^note]: ../note.md

          Text before
          [para]: ../para.md

          [words]: ../a.md and more
          [title]: ../a.md "unclosed
        MD

        expect(transformer.transform(content, options)).to eq(content)
      end

      it 'leaves definitions in code unchanged' do
        content = <<~MD
          ```md
          [fc]: ../intro.md
          ```

              [ic]: ../intro.md

          `[span]: ../intro.md`
        MD

        expect(transformer.transform(content, options)).to eq(content)
      end
    end

    context 'with code in the content' do
      let(:options) { { base_url: 'https://example.com/docs', source_path: 'guides/sub/page.md' } }

      it 'leaves links in inline code unchanged' do
        content = 'Write `[ic](../intro.md)` or ``[a `b`](../intro.md)`` to link.'
        result = transformer.transform(content, options)

        expect(result).to eq(content)
      end

      it 'leaves links in fenced code blocks unchanged' do
        content = <<~MD
          ```md
          [fc](../intro.md)
          ```

          ~~~~
          [tilde](../intro.md)
          ~~~~
        MD
        result = transformer.transform(content, options)

        expect(result).to eq(content)
      end

      it 'leaves links in fenced code blocks inside list items unchanged' do
        content = <<~MD
          - Item

              ```md
              [fc](../intro.md)
              ```
        MD
        result = transformer.transform(content, options)

        expect(result).to eq(content)
      end

      it 'leaves links in unclosed fenced code blocks unchanged' do
        content = "```\n[fc](../intro.md)\n"
        result = transformer.transform(content, options)

        expect(result).to eq(content)
      end

      it 'leaves links in indented code blocks unchanged' do
        content = "Example:\n\n    [icb](../intro.md)\n\tmore [tab](../intro.md)\n"
        result = transformer.transform(content, options)

        expect(result).to eq(content)
      end

      it 'leaves links in code blocks inside blockquotes unchanged' do
        content = <<~MD
          > ```md
          > [fc](../intro.md)
          > ```
          >
          >     [icb](../intro.md)
          > [quoted](../quoted.md)
        MD
        result = transformer.transform(content, options)

        expect(result).to eq(<<~MD)
          > ```md
          > [fc](../intro.md)
          > ```
          >
          >     [icb](../intro.md)
          > [quoted](https://example.com/docs/guides/quoted.md)
        MD
      end

      it 'does not close a fence on a fence line quoted deeper than the fence' do
        content = <<~MD
          ```md
          > ```
          > [fc](../intro.md)
          > ```
          ```

          > ```md
          > > ```
          > > [qfc](../intro.md)
          > > ```
          > ```

          [After](../after.md)
        MD
        result = transformer.transform(content, options)

        expect(result).to eq(<<~MD)
          ```md
          > ```
          > [fc](../intro.md)
          > ```
          ```

          > ```md
          > > ```
          > > [qfc](../intro.md)
          > > ```
          > ```

          [After](https://example.com/docs/guides/after.md)
        MD
      end

      it 'keeps CRLF line endings without link options' do
        content = "```\r\n[fc](../intro.md)\r\n```\r\n[After](../after.md)\r\n"
        result = transformer.transform(content)

        expect(result).to eq(content)
      end

      it 'keeps CRLF line endings when expanding links' do
        content = "```\r\n[fc](../intro.md)\r\n```\r\n[After](../after.md)\r\n"
        result = transformer.transform(content, options)

        expect(result).to eq("```\r\n[fc](../intro.md)\r\n```\r\n[After](https://example.com/docs/guides/after.md)\r\n")
      end

      it 'treats an indented fence as indented code' do
        content = "Example:\n\n    ```\n    [icb](../intro.md)\n\n[After](../after.md)\n"
        result = transformer.transform(content, options)

        expect(result).to eq("Example:\n\n    ```\n    [icb](../intro.md)\n\n[After](https://example.com/docs/guides/after.md)\n")
      end

      it 'expands links between escaped backticks' do
        content = '\\`[a](../a.md)\\`'
        result = transformer.transform(content, options)

        expect(result).to eq('\\`[a](https://example.com/docs/guides/a.md)\\`')
      end

      it 'expands links next to code' do
        content = <<~MD
          Use [`config`](../config.md) with `code`.

          ```
          [fc](../intro.md)
          ```
          [After](../after.md)
        MD
        result = transformer.transform(content, options)

        expect(result).to eq(<<~MD)
          Use [`config`](https://example.com/docs/guides/config.md) with `code`.

          ```
          [fc](../intro.md)
          ```
          [After](https://example.com/docs/guides/after.md)
        MD
      end

      it 'expands links in indented paragraph and list item continuations' do
        content = <<~MD
          Text
              [lazy](../lazy.md)

          - Item

              [nested](../nested.md)
        MD
        result = transformer.transform(content, options)

        expect(result).to eq(<<~MD)
          Text
              [lazy](https://example.com/docs/guides/lazy.md)

          - Item

              [nested](https://example.com/docs/guides/nested.md)
        MD
      end

      it 'leaves links whose destination runs into code unchanged' do
        content = <<~MD
          See [the API](../api.md for details.

          ```ruby
          client.call(1)
          ```

          Read [paren title](../a.md (see `run()`)) and [a](<../a`b`.md>).

          That is all (really). [Next](../next.md)
        MD
        result = transformer.transform(content, options)

        expect(result).to eq(<<~MD)
          See [the API](../api.md for details.

          ```ruby
          client.call(1)
          ```

          Read [paren title](../a.md (see `run()`)) and [a](<../a`b`.md>).

          That is all (really). [Next](https://example.com/docs/guides/next.md)
        MD
      end

      it 'expands links after a destination that runs into code' do
        content = <<~MD
          See [a](../a.md and `f()` then [b](../b.md).

          See [the API](../api.md for details.

          ```ruby
          client.call(1)
          ```

          Next: [intro](intro.md)
        MD
        result = transformer.transform(content, options)

        expect(result).to eq(<<~MD)
          See [a](../a.md and `f()` then [b](https://example.com/docs/guides/b.md).

          See [the API](../api.md for details.

          ```ruby
          client.call(1)
          ```

          Next: [intro](https://example.com/docs/guides/sub/intro.md)
        MD
      end

      it 'expands links with code in the title' do
        content = <<~MD
          See [run](../cli.md "Run `bin/x`") and [x](../x.md 'Call `f()`').
        MD
        result = transformer.transform(content, options)

        expect(result).to eq(<<~MD)
          See [run](https://example.com/docs/guides/cli.md "Run `bin/x`") and [x](https://example.com/docs/guides/x.md 'Call `f()`').
        MD
      end

      it 'leaves code unchanged with convert_urls and simplify_links' do
        content = "`[see the docs](https://example.com/a.html)`\n"
        result = transformer.transform(content, convert_urls: true, simplify_links: true)

        expect(result).to eq(content)
      end

      it 'keeps inline code at the start and end of link text with simplify_links' do
        content = "Use [`Config`](config.md) and [see the `run` docs](../cli.md).\n"
        result = transformer.transform(content, simplify_links: true)

        expect(result).to eq("Use [`Config`](config.md) and [`run`](../cli.md).\n")
      end

      it 'simplifies links after a destination that runs into code' do
        content = "See [the API](../api.md and `f()` then [see the docs](b.md).\n"
        result = transformer.transform(content, simplify_links: true)

        expect(result).to eq("See [the API](../api.md and `f()` then [docs](b.md).\n")
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

      it 'converts .html URLs with anchors and queries' do
        content = '[A](https://example.com/doc.html#sec) [B](https://example.com/doc.html?x=1) ' \
                  'see https://example.com/doc.htm#top'
        result = transformer.transform(content, convert_urls: true)

        expect(result).to eq(
          '[A](https://example.com/doc.md#sec) [B](https://example.com/doc.md?x=1) ' \
          'see https://example.com/doc.md#top'
        )
      end

      it 'converts relative .html link targets' do
        content = '[A](../intro.html) [B](guide.htm#setup) [C](/api/index.html?v=2 "API")'
        result = transformer.transform(content, convert_urls: true)

        expect(result).to eq('[A](../intro.md) [B](guide.md#setup) [C](/api/index.md?v=2 "API")')
      end

      it 'leaves .html in queries, anchors and non-http schemes unchanged' do
        content = '[A](https://example.com/page?next=a.html) [B](#a.html) [C](mailto:a@b.html) ' \
                  '[D](ftp://example.com/a.html)'
        result = transformer.transform(content, convert_urls: true)

        expect(result).to eq(content)
      end

      it 'leaves .html targets with any other URI scheme unchanged' do
        content = '[A](sftp://host/a.html) [B](file:///a.html) [C](javascript:void.html)'
        result = transformer.transform(content, convert_urls: true)

        expect(result).to eq(content)
      end

      it 'converts .html targets of link reference definitions' do
        content = <<~MD
          [a]: ../intro.html#x "Intro"
          [b]: guide.htm?v=2
          [c]: https://example.com/doc.html
          [d]: sftp://host/a.html
          [e]: page?next=a.html
        MD
        result = transformer.transform(content, convert_urls: true)

        expect(result).to eq(<<~MD)
          [a]: ../intro.md#x "Intro"
          [b]: guide.md?v=2
          [c]: https://example.com/doc.md
          [d]: sftp://host/a.html
          [e]: page?next=a.html
        MD
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

      it 'expands and converts .html targets of link reference definitions' do
        content = <<~MD
          [a]: ../intro.html#x "Intro"
          [b]: /api.htm?v=2
          [c]: sftp://host/a.html
        MD

        expect(transformer.transform(content, base_url: 'https://example.com/docs/', convert_urls: true))
          .to eq(<<~MD)
            [a]: https://example.com/intro.md#x "Intro"
            [b]: https://example.com/docs/api.md?v=2
            [c]: sftp://host/a.html
          MD
        expect(transformer.transform(content, base_url: '/docs/', source_path: 'guides/page.md', convert_urls: true))
          .to eq(<<~MD)
            [a]: /docs/intro.md#x "Intro"
            [b]: /docs/api.md?v=2
            [c]: sftp://host/a.html
          MD
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
