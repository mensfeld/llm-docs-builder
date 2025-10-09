# frozen_string_literal: true

RSpec.describe LlmDocsBuilder::OutputFormatter do
  describe '.format_bytes' do
    it 'formats bytes when less than 1 KB' do
      expect(described_class.format_bytes(512)).to eq('512 bytes')
    end

    it 'formats kilobytes when less than 1 MB' do
      expect(described_class.format_bytes(1024)).to eq('1.0 KB')
      expect(described_class.format_bytes(2048)).to eq('2.0 KB')
    end

    it 'formats megabytes when 1 MB or more' do
      expect(described_class.format_bytes(1_048_576)).to eq('1.0 MB')
      expect(described_class.format_bytes(2_621_440)).to eq('2.5 MB')
    end
  end

  describe '.format_number' do
    it 'formats small numbers without commas' do
      expect(described_class.format_number(123)).to eq('123')
    end

    it 'formats thousands with commas' do
      expect(described_class.format_number(1234)).to eq('1,234')
      expect(described_class.format_number(12_345)).to eq('12,345')
    end

    it 'formats millions with commas' do
      expect(described_class.format_number(1_234_567)).to eq('1,234,567')
    end
  end

  describe '.display_comparison_results' do
    it 'displays reduction results' do
      result = {
        human_size: 1000,
        ai_size: 500,
        reduction_bytes: 500,
        reduction_percent: 50,
        factor: 2.0,
        human_tokens: 250,
        ai_tokens: 125,
        token_reduction: 125,
        token_reduction_percent: 50,
        human_source: 'https://example.com',
        ai_source: 'docs/page.md'
      }

      expect do
        described_class.display_comparison_results(result)
      end.to output(/Context Window Comparison/).to_stdout
    end

    it 'displays increase results when AI version is larger' do
      result = {
        human_size: 500,
        ai_size: 1000,
        reduction_bytes: -500,
        reduction_percent: -100,
        factor: 0.5,
        human_tokens: 125,
        ai_tokens: 250,
        token_reduction: -125,
        token_reduction_percent: -100,
        human_source: 'https://example.com',
        ai_source: 'docs/page.md'
      }

      expect do
        described_class.display_comparison_results(result)
      end.to output(/Increase/).to_stdout
    end

    it 'displays same size message when sizes are equal' do
      result = {
        human_size: 500,
        ai_size: 500,
        reduction_bytes: 0,
        reduction_percent: 0,
        factor: 1.0,
        human_tokens: 125,
        ai_tokens: 125,
        token_reduction: 0,
        token_reduction_percent: 0,
        human_source: 'https://example.com',
        ai_source: 'docs/page.md'
      }

      expect do
        described_class.display_comparison_results(result)
      end.to output(/Same size/).to_stdout
    end
  end
end
