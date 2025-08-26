# frozen_string_literal: true

require 'net/http'
require 'json'

module LlmsTxt
  module Providers
    class OpenAI < Base
      OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions'
      DEFAULT_MODEL = 'gpt-4-turbo-preview'

      def complete(prompt)
        validate_api_key!

        response = make_request(build_payload(prompt))
        extract_content(response)
      end

      private

      def make_request(payload)
        uri = URI(OPENAI_API_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 60

        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request['Authorization'] = "Bearer #{configuration.api_key}"

        request.body = payload.to_json

        response = http.request(request)
        handle_response(response)
      rescue Net::ReadTimeout
        raise GenerationError, 'Request timed out. Please try again.'
      rescue StandardError => e
        raise GenerationError, "Failed to connect to OpenAI API: #{e.message}"
      end

      def build_payload(prompt)
        {
          model: configuration.model || DEFAULT_MODEL,
          messages: [
            {
              role: 'system',
              content: 'You are an expert Ruby developer generating llms.txt files. Output only the markdown content without any additional explanations.'
            },
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
        content = response.dig('choices', 0, 'message', 'content')

        raise GenerationError, 'No content received from OpenAI API' unless content

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
