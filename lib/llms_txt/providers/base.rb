# frozen_string_literal: true

module LlmsTxt
  module Providers
    class Base
      attr_reader :configuration

      def initialize(configuration)
        @configuration = configuration
      end

      def complete(prompt)
        raise NotImplementedError, "#{self.class} must implement #complete"
      end

      protected

      def validate_api_key!
        return if configuration.api_key && !configuration.api_key.empty?

        raise ConfigurationError, "API key not configured for #{self.class.name.split('::').last} provider"
      end

      def default_headers
        {
          'Content-Type' => 'application/json'
        }
      end

      def handle_response(response)
        case response
        when Net::HTTPSuccess
          parse_response(response.body)
        when Net::HTTPUnauthorized
          raise ConfigurationError, 'Invalid API key'
        when Net::HTTPTooManyRequests
          raise GenerationError, 'Rate limit exceeded. Please try again later.'
        else
          raise GenerationError, "API request failed: #{response.code} #{response.message}"
        end
      end

      def parse_response(body)
        JSON.parse(body)
      rescue JSON::ParserError => e
        raise GenerationError, "Failed to parse API response: #{e.message}"
      end
    end
  end
end
