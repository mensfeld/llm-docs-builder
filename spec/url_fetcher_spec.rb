# frozen_string_literal: true

require 'llm_docs_builder/url_fetcher'

RSpec.describe LlmDocsBuilder::UrlFetcher do
  let(:user_agent) { 'Test-Agent/1.0' }

  describe '#fetch' do
    it 'configures HTTP client with SSL for HTTPS URLs' do
      http = instance_double(Net::HTTP)
      expect(Net::HTTP).to receive(:new).with('example.com', 443).and_return(http)
      expect(http).to receive(:use_ssl=).with(true)
      expect(http).to receive(:open_timeout=).with(10)
      expect(http).to receive(:read_timeout=).with(30)

      response = Net::HTTPSuccess.new('1.1', '200', 'OK')
      allow(response).to receive(:body).and_return('fetched content')
      expect(http).to receive(:request) do |request|
        expect(request['User-Agent']).to eq(user_agent)
        response
      end

      fetcher = described_class.new(user_agent: user_agent)
      result = fetcher.fetch('https://example.com/path')
      expect(result).to eq('fetched content')
    end

    it 'follows redirects and logs when verbose' do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)

      redirect_response = Net::HTTPFound.new('1.1', '302', 'Found')
      allow(redirect_response).to receive(:[]).with('location').and_return('/new-path')
      success_response = Net::HTTPSuccess.new('1.1', '200', 'OK')
      allow(success_response).to receive(:body).and_return('redirected content')

      allow(http).to receive(:request).and_return(redirect_response, success_response)

      output = StringIO.new
      fetcher = described_class.new(user_agent: user_agent, verbose: true, output: output)
      result = fetcher.fetch('https://example.com/old-path')

      expect(result).to eq('redirected content')
      expect(output.string).to include('Redirecting to https://example.com/new-path')
    end

    it 'raises error for non-success HTTP responses' do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)

      error_response = Net::HTTPNotFound.new('1.1', '404', 'Not Found')
      allow(error_response).to receive(:code).and_return('404')
      allow(error_response).to receive(:message).and_return('Not Found')
      allow(http).to receive(:request).and_return(error_response)

      fetcher = described_class.new(user_agent: user_agent)

      expect do
        fetcher.fetch('https://example.com/missing')
      end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /Failed to fetch.*404/)
    end

    it 'wraps network errors in GenerationError' do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_raise(SocketError.new('network unreachable'))

      fetcher = described_class.new(user_agent: user_agent)

      expect do
        fetcher.fetch('https://example.com/path')
      end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /network unreachable/)
    end

    it 'limits redirect depth' do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)

      redirect_response = Net::HTTPFound.new('1.1', '302', 'Found')
      allow(redirect_response).to receive(:[]).with('location').and_return('/loop')
      allow(http).to receive(:request).and_return(*Array.new(described_class::MAX_REDIRECTS + 1, redirect_response))

      fetcher = described_class.new(user_agent: user_agent)

      expect do
        fetcher.fetch('https://example.com/loop')
      end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /Too many redirects/)
    end

    it 'rejects unsupported URL schemes' do
      fetcher = described_class.new(user_agent: user_agent)

      expect do
        fetcher.fetch('ftp://example.com/file')
      end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /Unsupported URL scheme/)
    end

    it 'rejects URLs without host' do
      fetcher = described_class.new(user_agent: user_agent)

      expect do
        fetcher.fetch('https://')
      end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /missing host/)
    end

    it 'rejects invalid redirect targets' do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)

      redirect_response = Net::HTTPFound.new('1.1', '302', 'Found')
      allow(redirect_response).to receive(:[]).with('location').and_return(nil)
      allow(http).to receive(:request).and_return(redirect_response)

      fetcher = described_class.new(user_agent: user_agent)

      expect do
        fetcher.fetch('https://example.com/redirect')
      end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /Redirect missing location/)
    end
  end
end

