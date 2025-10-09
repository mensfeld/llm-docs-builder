# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmsTxt::Comparator do
  let(:url) { 'https://example.com/docs/page.html' }
  let(:human_content) { "<html><body>#{'x' * 1000}</body></html>" }
  let(:ai_content) { 'x' * 500 }

  describe '#compare' do
    context 'when comparing remote versions with different User-Agents' do
      it 'fetches both versions and calculates reduction' do
        comparator = described_class.new(url)

        # Mock HTTP requests
        allow(comparator).to receive(:fetch_url)
          .with(url, described_class::HUMAN_USER_AGENT)
          .and_return(human_content)

        allow(comparator).to receive(:fetch_url)
          .with(url, described_class::AI_USER_AGENT)
          .and_return(ai_content)

        result = comparator.compare

        expect(result[:human_size]).to eq(human_content.bytesize)
        expect(result[:ai_size]).to eq(ai_content.bytesize)
        expect(result[:reduction_bytes]).to eq(human_content.bytesize - ai_content.bytesize)
        expect(result[:reduction_percent]).to be_within(1).of(51)
        expect(result[:factor]).to be_within(0.1).of(2.1)
        expect(result[:human_source]).to include(url)
        expect(result[:ai_source]).to include(url)
      end

      it 'handles verbose mode' do
        comparator = described_class.new(url, verbose: true)

        allow(comparator).to receive(:fetch_url).and_return('test')

        expect { comparator.compare }.to output(/Fetching/).to_stdout
      end
    end

    context 'when comparing remote URL with local file' do
      let(:local_file) { 'spec/fixtures/test.md' }

      before do
        FileUtils.mkdir_p('spec/fixtures')
        File.write(local_file, ai_content)
      end

      after do
        FileUtils.rm_f(local_file)
      end

      it 'fetches remote and reads local file' do
        comparator = described_class.new(url, local_file: local_file)

        allow(comparator).to receive(:fetch_url)
          .with(url, described_class::HUMAN_USER_AGENT)
          .and_return(human_content)

        result = comparator.compare

        expect(result[:human_size]).to eq(human_content.bytesize)
        expect(result[:ai_size]).to eq(ai_content.bytesize)
        expect(result[:reduction_bytes]).to eq(human_content.bytesize - ai_content.bytesize)
        expect(result[:human_source]).to eq(url)
        expect(result[:ai_source]).to eq(local_file)
      end

      it 'raises error if local file does not exist' do
        comparator = described_class.new(url, local_file: 'nonexistent.md')

        expect do
          comparator.compare
        end.to raise_error(LlmsTxt::Errors::GenerationError, /not found/)
      end
    end

    context 'when AI version is larger' do
      let(:human_content) { 'x' * 100 }
      let(:ai_content) { 'x' * 200 }

      it 'calculates negative reduction' do
        comparator = described_class.new(url)

        allow(comparator).to receive(:fetch_url).and_return(human_content, ai_content)

        result = comparator.compare

        expect(result[:reduction_bytes]).to eq(-100)
        expect(result[:reduction_percent]).to eq(-100)
        expect(result[:factor]).to eq(0.5)
      end
    end

    context 'when sizes are equal' do
      let(:content) { 'x' * 500 }

      it 'shows zero reduction' do
        comparator = described_class.new(url)

        allow(comparator).to receive(:fetch_url).and_return(content, content)

        result = comparator.compare

        expect(result[:reduction_bytes]).to eq(0)
        expect(result[:reduction_percent]).to eq(0)
        expect(result[:factor]).to eq(1.0)
      end
    end
  end

  describe 'error handling' do
    it 'raises error on network failure' do
      comparator = described_class.new(url)

      allow(Net::HTTP).to receive(:new).and_raise(SocketError.new('getaddrinfo: Name or service not known'))

      expect do
        comparator.compare
      end.to raise_error(LlmsTxt::Errors::GenerationError, /Error fetching/)
    end
  end

  describe 'redirect handling' do
    it 'limits redirect depth to prevent infinite loops' do
      comparator = described_class.new(url)

      # Mock fetch_url to simulate hitting the redirect limit
      allow(comparator).to receive(:fetch_url) do |_url, _ua, redirect_count = 0|
        if redirect_count >= described_class::MAX_REDIRECTS
          raise LlmsTxt::Errors::GenerationError,
            "Too many redirects (#{described_class::MAX_REDIRECTS}) when fetching #{url}"
        end

        # Simulate recursive redirect
        comparator.send(:fetch_url, url, 'test', redirect_count + 1)
      end

      expect do
        comparator.compare
      end.to raise_error(LlmsTxt::Errors::GenerationError, /Too many redirects/)
    end

    it 'includes redirect count in error message' do
      comparator = described_class.new(url)

      allow(comparator).to receive(:fetch_url) do
        raise LlmsTxt::Errors::GenerationError,
          "Too many redirects (10) when fetching #{url}"
      end

      expect do
        comparator.compare
      end.to raise_error(LlmsTxt::Errors::GenerationError, /10/)
    end
  end

  describe 'URL validation' do
    it 'rejects non-HTTP/HTTPS schemes' do
      comparator = described_class.new('ftp://example.com/file.txt')

      expect do
        comparator.compare
      end.to raise_error(LlmsTxt::Errors::GenerationError, /Unsupported URL scheme/)
    end

    it 'rejects file:// scheme' do
      comparator = described_class.new('file:///etc/passwd')

      expect do
        comparator.compare
      end.to raise_error(LlmsTxt::Errors::GenerationError, /Unsupported URL scheme/)
    end

    it 'rejects javascript: scheme' do
      comparator = described_class.new('javascript:alert(1)')

      expect do
        comparator.compare
      end.to raise_error(LlmsTxt::Errors::GenerationError, /Unsupported URL scheme/)
    end

    it 'rejects URLs without scheme' do
      comparator = described_class.new('example.com/page')

      expect do
        comparator.compare
      end.to raise_error(LlmsTxt::Errors::GenerationError, /Unsupported URL scheme/)
    end

    it 'rejects URLs without host' do
      comparator = described_class.new('http://')

      expect do
        comparator.compare
      end.to raise_error(LlmsTxt::Errors::GenerationError, /missing host/)
    end

    it 'rejects malformed URLs' do
      comparator = described_class.new('http://[invalid')

      expect do
        comparator.compare
      end.to raise_error(LlmsTxt::Errors::GenerationError, /Invalid URL format/)
    end

    it 'accepts valid HTTP URLs' do
      comparator = described_class.new('http://example.com/page')

      allow(comparator).to receive(:fetch_url).and_return('content')

      expect { comparator.compare }.not_to raise_error
    end

    it 'accepts valid HTTPS URLs' do
      comparator = described_class.new('https://example.com/page')

      allow(comparator).to receive(:fetch_url).and_return('content')

      expect { comparator.compare }.not_to raise_error
    end
  end

  describe 'custom User-Agents' do
    it 'allows custom User-Agent for human version' do
      custom_ua = 'Custom-Browser/1.0'
      comparator = described_class.new(url, human_user_agent: custom_ua)

      expect(comparator).to receive(:fetch_url).with(url, custom_ua).and_return('test')
      expect(comparator).to receive(:fetch_url)
        .with(url, described_class::AI_USER_AGENT)
        .and_return('test')

      comparator.compare
    end

    it 'allows custom User-Agent for AI version' do
      custom_ua = 'Custom-AI/1.0'
      comparator = described_class.new(url, ai_user_agent: custom_ua)

      expect(comparator).to receive(:fetch_url)
        .with(url, described_class::HUMAN_USER_AGENT)
        .and_return('test')
      expect(comparator).to receive(:fetch_url).with(url, custom_ua).and_return('test')

      comparator.compare
    end
  end
end
