# frozen_string_literal: true

RSpec.describe LlmDocsBuilder::TokenEstimator do
  describe '#estimate' do
    let(:estimator) { described_class.new }

    it 'estimates tokens using 4 characters per token heuristic' do
      content = 'test' * 100 # 400 characters
      expected_tokens = (400 / 4.0).round # 100 tokens

      result = estimator.estimate(content)

      expect(result).to eq(expected_tokens)
    end

    it 'handles empty content' do
      result = estimator.estimate('')

      expect(result).to eq(0)
    end

    it 'handles nil content' do
      result = estimator.estimate(nil)

      expect(result).to eq(0)
    end

    it 'handles small content' do
      content = 'hi' # 2 characters
      expected_tokens = (2 / 4.0).round # 1 token (rounded)

      result = estimator.estimate(content)

      expect(result).to eq(expected_tokens)
    end

    it 'provides reasonable estimates for documentation content' do
      # Typical documentation paragraph
      content = <<~TEXT
        This is a typical documentation paragraph that explains how to use the API.
        It contains multiple sentences with technical information about the endpoints,
        parameters, and return values. The token estimation should be reasonably accurate
        for this type of content.
      TEXT

      result = estimator.estimate(content)

      # Should be roughly 1/4 of character count
      expect(result).to be_within(5).of(content.length / 4)
    end

    it 'allows custom characters per token' do
      estimator = described_class.new(chars_per_token: 3.0)
      content = 'test' * 30 # 120 characters

      result = estimator.estimate(content)

      expect(result).to eq(40) # 120 / 3 = 40
    end
  end

  describe '.estimate' do
    it 'provides class method for convenience' do
      content = 'test' * 25 # 100 characters

      result = described_class.estimate(content)

      expect(result).to eq(25) # 100 / 4 = 25
    end

    it 'accepts custom characters per token' do
      content = 'test' * 25 # 100 characters

      result = described_class.estimate(content, chars_per_token: 5.0)

      expect(result).to eq(20) # 100 / 5 = 20
    end
  end
end
