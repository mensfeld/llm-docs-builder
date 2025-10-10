# frozen_string_literal: true

RSpec.describe LlmDocsBuilder::TextCompressor do
  subject(:compressor) { described_class.new }

  describe '#compress' do
    context 'with remove_stopwords option' do
      it 'removes common stopwords from prose' do
        content = 'This is a simple guide to the API. The API provides access to the data.'
        result = compressor.compress(content, remove_stopwords: true)

        stopword_count_before = content.scan(/\bthe\b/i).length
        stopword_count_after = result.scan(/\bthe\b/i).length

        expect(stopword_count_after).to be < stopword_count_before
      end

      it 'preserves code blocks' do
        content = <<~MD
          This is the guide.

          ```ruby
          # Use the API
          the_value = get_the_data()
          ```

          The end.
        MD

        result = compressor.compress(content, remove_stopwords: true)

        expect(result).to include('```ruby')
        expect(result).to include('the_value = get_the_data()')
        expect(result).to include('# Use the API')
      end

      it 'preserves inline code' do
        content = 'Use the `get_the_value()` method to access the data.'
        result = compressor.compress(content, remove_stopwords: true)

        expect(result).to include('`get_the_value()`')
      end

      it 'removes various stopwords' do
        content = 'This is a test of the system with an example and some data.'
        result = compressor.compress(content, remove_stopwords: true)

        # Should remove: this, is, a, of, the, with, an, and, some
        expect(result.length).to be < content.length
        expect(result).to include('test')
        expect(result).to include('system')
        expect(result).to include('example')
        expect(result).to include('data')
      end

      it 'handles case-insensitive stopwords' do
        content = 'The API is available. THE system IS ready.'
        result = compressor.compress(content, remove_stopwords: true)

        expect(result.length).to be < content.length
        expect(result).to include('API')
        expect(result).to include('system')
      end

      it 'preserves word boundaries' do
        content = 'The theater theme is authentic.'
        result = compressor.compress(content, remove_stopwords: true)

        # "the" in "theater" and "theme" should not be removed
        expect(result).to include('theater')
        expect(result).to include('theme')
        expect(result).to include('authentic')
      end

      it 'handles empty content' do
        content = ''
        result = compressor.compress(content, remove_stopwords: true)

        expect(result).to eq('')
      end

      it 'handles content with only stopwords' do
        content = 'the a an is are was were'
        result = compressor.compress(content, remove_stopwords: true)

        expect(result.strip).to be_empty
      end
    end

    context 'with remove_duplicates option' do
      it 'removes duplicate paragraphs' do
        content = <<~MD
          # Guide

          This is important information.

          This is important information.

          Different content here.
        MD

        result = compressor.compress(content, remove_duplicates: true)

        occurrences = result.scan(/This is important information/).length
        expect(occurrences).to eq(1)
        expect(result).to include('Different content here')
      end

      it 'uses normalization for comparison' do
        content = <<~MD
          # Guide

          This is important information.

          this is important INFORMATION.

          Different content.
        MD

        result = compressor.compress(content, remove_duplicates: true)

        # Both versions should be considered duplicates
        occurrences = result.scan(/important information/i).length
        expect(occurrences).to eq(1)
      end

      it 'preserves headings' do
        content = <<~MD
          # Title

          ## Section 1

          Content here.

          Content here.

          ## Section 2
        MD

        result = compressor.compress(content, remove_duplicates: true)

        expect(result).to include('# Title')
        expect(result).to include('## Section 1')
        expect(result).to include('## Section 2')
        expect(result.scan(/Content here/).length).to eq(1)
      end

      it 'handles empty paragraphs' do
        content = <<~MD
          Content 1



          Content 1
        MD

        result = compressor.compress(content, remove_duplicates: true)

        occurrences = result.scan(/Content 1/).length
        expect(occurrences).to eq(1)
      end

      it 'preserves unique paragraphs' do
        content = <<~MD
          Paragraph 1

          Paragraph 2

          Paragraph 3
        MD

        result = compressor.compress(content, remove_duplicates: true)

        expect(result).to include('Paragraph 1')
        expect(result).to include('Paragraph 2')
        expect(result).to include('Paragraph 3')
      end

      it 'handles content with no duplicates' do
        content = <<~MD
          # Title

          Unique content 1.

          Unique content 2.

          Unique content 3.
        MD

        result = compressor.compress(content, remove_duplicates: true)

        expect(result).to include('Unique content 1')
        expect(result).to include('Unique content 2')
        expect(result).to include('Unique content 3')
      end
    end

    context 'with both remove_stopwords and remove_duplicates' do
      it 'applies both transformations' do
        content = <<~MD
          This is the first paragraph with the data.

          This is the first paragraph with the data.

          This is the second paragraph with the information.
        MD

        result = compressor.compress(content,
          remove_stopwords: true,
          remove_duplicates: true)

        # Should remove duplicates
        expect(result.scan(/first paragraph/).length).to eq(1)

        # Should remove stopwords
        stopword_count = result.scan(/\bthe\b/i).length
        original_stopword_count = content.scan(/\bthe\b/i).length
        expect(stopword_count).to be < original_stopword_count
      end
    end

    context 'with no compression methods' do
      it 'returns content unchanged' do
        content = <<~MD
          This is the content.

          This is the content.
        MD

        result = compressor.compress(content)

        expect(result).to eq(content)
      end
    end

    context 'with empty methods hash' do
      it 'returns content unchanged' do
        content = 'Test content.'
        result = compressor.compress(content, {})

        expect(result).to eq(content)
      end
    end

    context 'with false values' do
      it 'does not apply transformations' do
        content = 'This is the test. This is the test.'
        result = compressor.compress(content,
          remove_stopwords: false,
          remove_duplicates: false)

        expect(result).to eq(content)
      end
    end
  end
end
