# frozen_string_literal: true

require 'net/http'
require 'json'

module LlmsTxt
  module Providers
    class Claude < Base
      ANTHROPIC_API_URL = 'https://api.anthropic.com/v1/messages'
      DEFAULT_MODEL = 'claude-3-opus-20240229'
      API_VERSION = '2023-06-01'

      def complete(prompt)
        validate_api_key!

        response = make_request(build_payload(prompt))
        extract_content(response)
      end

      private

      def make_request(payload)
        uri = URI(ANTHROPIC_API_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 60

        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request['x-api-key'] = configuration.api_key
        request['anthropic-version'] = API_VERSION

        request.body = payload.to_json

        response = http.request(request)
        handle_response(response)
      rescue Net::ReadTimeout
        raise GenerationError, 'Request timed out. Please try again.'
      rescue StandardError => e
        raise GenerationError, "Failed to connect to Anthropic API: #{e.message}"
      end

      def build_payload(prompt)
        {
          model: configuration.model || DEFAULT_MODEL,
          messages: [
            {
              role: 'user',
              content: prompt
            }
          ],
          max_tokens: configuration.max_tokens || 4096,
          temperature: configuration.temperature || 0.3
        }
      end

      def extract_content(response)
        content = response.dig('content', 0, 'text')

        raise GenerationError, 'No content received from Claude API' unless content

        clean_content(content)
      end

      def clean_content(content)
        content = content.strip

        content = content.gsub(/^```markdown\s*\n/, '')
        content = content.gsub(/\n```\s*$/, '')
        content = content.gsub(/^```\s*\n/, '')

        content.strip
      end
    end
  end
end
