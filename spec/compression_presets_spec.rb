# frozen_string_literal: true

RSpec.describe LlmDocsBuilder::CompressionPresets do
  describe '.conservative' do
    it 'returns conservative preset options' do
      options = described_class.conservative

      expect(options[:remove_frontmatter]).to be true
      expect(options[:remove_comments]).to be true
      expect(options[:remove_badges]).to be true
      expect(options[:remove_images]).to be true
      expect(options[:normalize_whitespace]).to be true
    end

    it 'does not include aggressive options' do
      options = described_class.conservative

      expect(options[:remove_code_examples]).to be_nil
      expect(options[:remove_duplicates]).to be_nil
      expect(options[:remove_stopwords]).to be_nil
    end

    it 'does not include enhancements' do
      options = described_class.conservative

      expect(options[:generate_toc]).to be_nil
      expect(options[:custom_instruction]).to be_nil
    end
  end

  describe '.moderate' do
    it 'returns moderate preset options' do
      options = described_class.moderate

      expect(options[:remove_frontmatter]).to be true
      expect(options[:remove_comments]).to be true
      expect(options[:remove_badges]).to be true
      expect(options[:remove_images]).to be true
      expect(options[:normalize_whitespace]).to be true
      expect(options[:simplify_links]).to be true
      expect(options[:remove_blockquotes]).to be true
      expect(options[:generate_toc]).to be true
    end

    it 'includes all conservative options' do
      conservative = described_class.conservative
      moderate = described_class.moderate

      conservative.each do |key, value|
        expect(moderate[key]).to eq(value)
      end
    end

    it 'does not include code removal' do
      options = described_class.moderate

      expect(options[:remove_code_examples]).to be_nil
    end
  end

  describe '.aggressive' do
    it 'returns aggressive preset options' do
      options = described_class.aggressive

      expect(options[:remove_frontmatter]).to be true
      expect(options[:remove_comments]).to be true
      expect(options[:remove_badges]).to be true
      expect(options[:remove_images]).to be true
      expect(options[:normalize_whitespace]).to be true
      expect(options[:simplify_links]).to be true
      expect(options[:remove_blockquotes]).to be true
      expect(options[:generate_toc]).to be true
      expect(options[:remove_code_examples]).to be true
      expect(options[:remove_duplicates]).to be true
      expect(options[:remove_stopwords]).to be true
    end

    it 'includes all moderate options' do
      moderate = described_class.moderate
      aggressive = described_class.aggressive

      moderate.each do |key, value|
        expect(aggressive[key]).to eq(value)
      end
    end

    it 'is the most comprehensive preset' do
      options = described_class.aggressive

      # Should have the most options enabled
      expect(options.count).to be >= described_class.conservative.count
      expect(options.count).to be >= described_class.moderate.count
    end
  end

  describe '.documentation' do
    it 'returns documentation preset options' do
      options = described_class.documentation

      expect(options[:remove_frontmatter]).to be true
      expect(options[:remove_comments]).to be true
      expect(options[:remove_badges]).to be true
      expect(options[:remove_images]).to be true
      expect(options[:normalize_whitespace]).to be true
      expect(options[:simplify_links]).to be true
      expect(options[:remove_blockquotes]).to be true
      expect(options[:generate_toc]).to be true
      expect(options[:remove_duplicates]).to be true
    end

    it 'preserves code examples' do
      options = described_class.documentation

      expect(options[:remove_code_examples]).to be_nil
    end

    it 'includes custom instruction' do
      options = described_class.documentation

      expect(options[:custom_instruction]).to be_a(String)
      expect(options[:custom_instruction]).to include('optimized for AI consumption')
    end

    it 'accepts custom instruction parameter' do
      custom_instruction = 'Custom documentation context'
      options = described_class.documentation(custom_instruction: custom_instruction)

      expect(options[:custom_instruction]).to eq(custom_instruction)
    end

    it 'uses default instruction when not provided' do
      options = described_class.documentation

      expect(options[:custom_instruction]).not_to be_nil
      expect(options[:custom_instruction]).to be_a(String)
    end
  end

  describe '.tutorial' do
    it 'returns tutorial preset options' do
      options = described_class.tutorial

      expect(options[:remove_frontmatter]).to be true
      expect(options[:remove_comments]).to be true
      expect(options[:remove_badges]).to be true
      expect(options[:remove_images]).to be true
      expect(options[:normalize_whitespace]).to be true
      expect(options[:generate_toc]).to be true
    end

    it 'preserves code examples' do
      options = described_class.tutorial

      expect(options[:remove_code_examples]).to be_nil
    end

    it 'preserves blockquotes' do
      options = described_class.tutorial

      expect(options[:remove_blockquotes]).to be_nil
    end

    it 'includes tutorial-specific instruction' do
      options = described_class.tutorial

      expect(options[:custom_instruction]).to be_a(String)
      expect(options[:custom_instruction]).to include('tutorial')
      expect(options[:custom_instruction]).to include('step-by-step')
    end
  end

  describe '.api_reference' do
    it 'returns api_reference preset options' do
      options = described_class.api_reference

      expect(options[:remove_frontmatter]).to be true
      expect(options[:remove_comments]).to be true
      expect(options[:remove_badges]).to be true
      expect(options[:remove_images]).to be true
      expect(options[:remove_blockquotes]).to be true
      expect(options[:remove_duplicates]).to be true
      expect(options[:simplify_links]).to be true
      expect(options[:generate_toc]).to be true
      expect(options[:normalize_whitespace]).to be true
    end

    it 'includes API-specific instruction' do
      options = described_class.api_reference

      expect(options[:custom_instruction]).to be_a(String)
      expect(options[:custom_instruction]).to include('API reference')
      expect(options[:custom_instruction]).to include('method signatures')
    end
  end

  describe '.get' do
    it 'returns conservative preset by name' do
      options = described_class.get(:conservative)

      expect(options).to eq(described_class.conservative)
    end

    it 'returns moderate preset by name' do
      options = described_class.get(:moderate)

      expect(options).to eq(described_class.moderate)
    end

    it 'returns aggressive preset by name' do
      options = described_class.get(:aggressive)

      expect(options).to eq(described_class.aggressive)
    end

    it 'returns documentation preset by name' do
      options = described_class.get(:documentation)

      expect(options).to eq(described_class.documentation)
    end

    it 'returns tutorial preset by name' do
      options = described_class.get(:tutorial)

      expect(options).to eq(described_class.tutorial)
    end

    it 'returns api_reference preset by name' do
      options = described_class.get(:api_reference)

      expect(options).to eq(described_class.api_reference)
    end

    it 'accepts string preset names' do
      options = described_class.get('moderate')

      expect(options).to eq(described_class.moderate)
    end

    it 'raises error for unknown preset' do
      expect do
        described_class.get(:unknown_preset)
      end.to raise_error(ArgumentError, /Unknown preset: unknown_preset/)
    end

    it 'includes available presets in error message' do
      expect do
        described_class.get(:invalid)
      end.to raise_error(ArgumentError, /conservative/)
    end

    context 'with custom options' do
      it 'merges custom options with preset' do
        custom_options = { custom_instruction: 'Custom instruction', verbose: true }
        options = described_class.get(:moderate, custom_options)

        expect(options[:custom_instruction]).to eq('Custom instruction')
        expect(options[:verbose]).to be true
        expect(options[:generate_toc]).to be true # From preset
      end

      it 'allows overriding preset values' do
        custom_options = { remove_images: false }
        options = described_class.get(:conservative, custom_options)

        expect(options[:remove_images]).to be false
      end

      it 'works with empty custom options' do
        options = described_class.get(:moderate, {})

        expect(options).to eq(described_class.moderate)
      end
    end
  end

  describe 'preset hierarchy' do
    it 'has increasing compression levels' do
      conservative_count = described_class.conservative.count
      moderate_count = described_class.moderate.count
      aggressive_count = described_class.aggressive.count

      expect(moderate_count).to be > conservative_count
      expect(aggressive_count).to be > moderate_count
    end

    it 'maintains backward compatibility' do
      # All higher-level presets should include conservative options
      conservative = described_class.conservative
      moderate = described_class.moderate
      aggressive = described_class.aggressive

      conservative.each do |key, value|
        expect(moderate[key]).to eq(value), "moderate should include conservative #{key}"
        expect(aggressive[key]).to eq(value), "aggressive should include conservative #{key}"
      end
    end
  end

  describe 'preset characteristics' do
    it 'conservative is the safest' do
      options = described_class.conservative

      # Should only remove non-content elements
      expect(options[:remove_code_examples]).to be_nil
      expect(options[:remove_duplicates]).to be_nil
      expect(options[:remove_stopwords]).to be_nil
    end

    it 'moderate adds navigation and simplification' do
      options = described_class.moderate

      expect(options[:generate_toc]).to be true
      expect(options[:simplify_links]).to be true
      expect(options[:remove_blockquotes]).to be true
    end

    it 'aggressive applies all compression' do
      options = described_class.aggressive

      expect(options[:remove_code_examples]).to be true
      expect(options[:remove_duplicates]).to be true
      expect(options[:remove_stopwords]).to be true
    end

    it 'documentation preserves code' do
      options = described_class.documentation

      expect(options[:remove_code_examples]).to be_nil
      expect(options[:remove_duplicates]).to be true
      expect(options[:custom_instruction]).not_to be_nil
    end

    it 'tutorial is most preserving' do
      options = described_class.tutorial

      expect(options[:remove_code_examples]).to be_nil
      expect(options[:remove_blockquotes]).to be_nil
      expect(options[:generate_toc]).to be true
    end
  end
end
