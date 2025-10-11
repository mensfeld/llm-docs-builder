# frozen_string_literal: true

require 'llm_docs_builder/validator'

RSpec.describe LlmDocsBuilder::Validator do
  describe 'edge cases' do
    it 'detects title that is too long' do
      content = "# #{'A' * 90}\n\nContent here"
      validator = described_class.new(content)

      expect(validator.valid?).to be false
      expect(validator.errors).to include('Title is too long (max 80 characters)')
    end

    it 'detects description blockquote that is too long' do
      content = "# Title\n> #{'A' * 250}\n\n## Documentation"
      validator = described_class.new(content)

      expect(validator.valid?).to be false
      expect(validator.errors).to include('Description blockquote is too long (max 200 characters)')
    end

    it 'detects empty link text' do
      content = "# Title\n\n## Documentation\n- [](https://example.com)"
      validator = described_class.new(content)

      expect(validator.valid?).to be false
      expect(validator.errors).to include('Empty link text found')
    end

    # Note: This test intentionally not included as empty headers are caught by
    # the regex pattern which requires some text after the header marker

    it 'warns about headers deeper than H2' do
      content = "# Title\n\n### Deep Header\n\n## Documentation"
      validator = described_class.new(content)

      expect(validator.valid?).to be false
      expect(validator.errors).to include('Headers deeper than H2 not recommended (found H3)')
    end

    it 'warns about non-HTTPS URLs' do
      content = "# Title\n\n## Documentation\n- [Link](http://example.com/doc.md)"
      validator = described_class.new(content)

      expect(validator.valid?).to be false
      expect(validator.errors).to include('Non-HTTPS URL found: http://example.com/doc.md (consider using HTTPS)')
    end

    it 'detects file size exceeding maximum' do
      large_content = "# Title\n\n## Documentation\n" + ("- [Link](https://example.com/doc.md)\n" * 2000)
      validator = described_class.new(large_content)

      expect(validator.valid?).to be false
      expect(validator.errors).to include('File size exceeds maximum (50000 bytes)')
    end
  end
end
