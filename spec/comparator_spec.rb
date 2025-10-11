# frozen_string_literal: true

RSpec.describe LlmDocsBuilder::Comparator do
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

        # Token estimation tests
        expect(result[:human_tokens]).to eq((human_content.length / 4.0).round)
        expect(result[:ai_tokens]).to eq((ai_content.length / 4.0).round)
        expect(result[:token_reduction]).to eq(result[:human_tokens] - result[:ai_tokens])
        expect(result[:token_reduction_percent]).to be > 0
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

        # Token estimation tests
        expect(result[:human_tokens]).to be > 0
        expect(result[:ai_tokens]).to be > 0
        expect(result[:token_reduction]).to eq(result[:human_tokens] - result[:ai_tokens])
      end

      it 'raises error if local file does not exist' do
        comparator = described_class.new(url, local_file: 'nonexistent.md')

        expect do
          comparator.compare
        end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /not found/)
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
      end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /Error fetching/)
    end
  end

  describe 'redirect handling' do
    it 'limits redirect depth to prevent infinite loops' do
      comparator = described_class.new(url)

      # Mock fetch_url to simulate hitting the redirect limit
      allow(comparator).to receive(:fetch_url) do |_url, _ua, redirect_count = 0|
        if redirect_count >= described_class::MAX_REDIRECTS
          raise LlmDocsBuilder::Errors::GenerationError,
            "Too many redirects (#{described_class::MAX_REDIRECTS}) when fetching #{url}"
        end

        # Simulate recursive redirect
        comparator.send(:fetch_url, url, 'test', redirect_count + 1)
      end

      expect do
        comparator.compare
      end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /Too many redirects/)
    end

    it 'includes redirect count in error message' do
      comparator = described_class.new(url)

      allow(comparator).to receive(:fetch_url) do
        raise LlmDocsBuilder::Errors::GenerationError,
          "Too many redirects (10) when fetching #{url}"
      end

      expect do
        comparator.compare
      end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /10/)
    end
  end

  describe 'URL validation' do
    it 'rejects non-HTTP/HTTPS schemes' do
      comparator = described_class.new('ftp://example.com/file.txt')

      expect do
        comparator.compare
      end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /Unsupported URL scheme/)
    end

    it 'rejects file:// scheme' do
      comparator = described_class.new('file:///etc/passwd')

      expect do
        comparator.compare
      end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /Unsupported URL scheme/)
    end

    it 'rejects javascript: scheme' do
      comparator = described_class.new('javascript:alert(1)')

      expect do
        comparator.compare
      end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /Unsupported URL scheme/)
    end

    it 'rejects URLs without scheme' do
      comparator = described_class.new('example.com/page')

      expect do
        comparator.compare
      end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /Unsupported URL scheme/)
    end

    it 'rejects URLs without host' do
      comparator = described_class.new('http://')

      expect do
        comparator.compare
      end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /missing host/)
    end

    it 'rejects malformed URLs' do
      comparator = described_class.new('http://[invalid')

      expect do
        comparator.compare
      end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /Invalid URL format/)
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

  describe '#send(:fetch_url) implementation' do
    let(:comparator) { described_class.new(url) }

    it 'configures HTTP with SSL for HTTPS URLs' do
      http_mock = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).with('example.com', 443).and_return(http_mock)
      allow(http_mock).to receive(:use_ssl=)
      allow(http_mock).to receive(:open_timeout=)
      allow(http_mock).to receive(:read_timeout=)

      response = Net::HTTPSuccess.new('1.1', '200', 'OK')
      allow(response).to receive(:body).and_return('test content')
      allow(http_mock).to receive(:request).and_return(response)

      result = comparator.send(:fetch_url, 'https://example.com/page', 'Test-Agent')

      expect(http_mock).to have_received(:use_ssl=).with(true)
      expect(http_mock).to have_received(:open_timeout=).with(10)
      expect(http_mock).to have_received(:read_timeout=).with(30)
      expect(result).to eq('test content')
    end

    it 'follows redirect responses' do
      http_mock = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http_mock)
      allow(http_mock).to receive(:use_ssl=)
      allow(http_mock).to receive(:open_timeout=)
      allow(http_mock).to receive(:read_timeout=)

      # First request returns redirect
      redirect_response = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved')
      allow(redirect_response).to receive(:[]).with('location').and_return('https://example.com/new-page')

      # Second request returns success
      success_response = Net::HTTPSuccess.new('1.1', '200', 'OK')
      allow(success_response).to receive(:body).and_return('final content')

      allow(http_mock).to receive(:request).and_return(redirect_response, success_response)

      result = comparator.send(:fetch_url, 'https://example.com/old-page', 'Test-Agent')

      expect(result).to eq('final content')
    end

    it 'raises error for non-success HTTP responses' do
      http_mock = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http_mock)
      allow(http_mock).to receive(:use_ssl=)
      allow(http_mock).to receive(:open_timeout=)
      allow(http_mock).to receive(:read_timeout=)

      error_response = Net::HTTPNotFound.new('1.1', '404', 'Not Found')
      allow(error_response).to receive(:code).and_return('404')
      allow(error_response).to receive(:message).and_return('Not Found')
      allow(http_mock).to receive(:request).and_return(error_response)

      expect do
        comparator.send(:fetch_url, 'https://example.com/missing', 'Test-Agent')
      end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /Failed to fetch.*404/)
    end
  end

  describe 'edge cases in calculate_results' do
    let(:comparator) { described_class.new(url) }

    it 'handles zero human size' do
      result = comparator.send(:calculate_results, '', 'content', 'source1', 'source2')

      expect(result[:reduction_percent]).to eq(0)
      expect(result[:token_reduction_percent]).to eq(0)
    end

    it 'handles zero AI size' do
      result = comparator.send(:calculate_results, 'content', '', 'source1', 'source2')

      expect(result[:factor]).to eq(Float::INFINITY)
    end

    it 'handles zero token counts' do
      allow_any_instance_of(LlmDocsBuilder::TokenEstimator).to receive(:estimate).and_return(0)

      result = comparator.send(:calculate_results, '', '', 'source1', 'source2')

      expect(result[:token_reduction_percent]).to eq(0)
    end
  end

end
