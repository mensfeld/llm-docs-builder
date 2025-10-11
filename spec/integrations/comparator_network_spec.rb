# frozen_string_literal: true

require 'llm_docs_builder'

RSpec.describe 'Comparator Network Integration' do
  it 'fetches and compares real documentation from Karafka', :network do
    comparator = LlmDocsBuilder::Comparator.new('https://karafka.io/docs/')

    result = comparator.compare

    # Basic result structure validation
    expect(result).to include(
      :human_size,
      :ai_size,
      :reduction_bytes,
      :reduction_percent,
      :factor,
      :human_tokens,
      :ai_tokens,
      :token_reduction,
      :token_reduction_percent,
      :human_source,
      :ai_source
    )

    # Content should be fetched
    expect(result[:human_size]).to be > 0
    expect(result[:ai_size]).to be > 0

    # Token estimates should be reasonable
    expect(result[:human_tokens]).to be > 0
    expect(result[:ai_tokens]).to be > 0

    # Sources should be correct
    expect(result[:human_source]).to include('karafka.io')
    expect(result[:ai_source]).to include('karafka.io')
  end

  it 'handles HTTP redirects gracefully', :network do
    # This URL redirects to HTTPS
    comparator = LlmDocsBuilder::Comparator.new('http://karafka.io/docs/', verbose: true)

    expect do
      result = comparator.compare
      expect(result[:human_size]).to be > 0
    end.to output(/Fetching/).to_stdout
  end
end
