# frozen_string_literal: true

module LlmsTxt
  class Configuration
    attr_accessor :llm_provider, :api_key, :model, :temperature, :max_tokens,
                  :output_path, :include_optional, :file_analyzers,
                  :exclude_patterns, :include_patterns, :yard_options,
                  :auto_detect_docs, :verbose

    def initialize
      @llm_provider = :claude
      @api_key = ENV['ANTHROPIC_API_KEY'] || ENV.fetch('OPENAI_API_KEY', nil)
      @model = default_model
      @temperature = 0.3
      @max_tokens = 4096
      @output_path = 'llms.txt'
      @include_optional = true
      @file_analyzers = default_analyzers
      @exclude_patterns = default_exclude_patterns
      @include_patterns = []
      @yard_options = {}
      @auto_detect_docs = true
      @verbose = false
    end

    def llm_client
      @llm_client ||= case llm_provider
                      when :claude
                        Providers::Claude.new(self)
                      when :openai
                        Providers::OpenAI.new(self)
                      when :local
                        Providers::Local.new(self)
                      else
                        raise ConfigurationError, "Unknown LLM provider: #{llm_provider}"
                      end
    end

    private

    def default_model
      case llm_provider
      when :claude then 'claude-3-opus-20240229'
      when :openai then 'gpt-4-turbo-preview'
      else 'llama-2-70b'
      end
    end

    def default_analyzers
      %i[readme gemspec yard changelog examples docs wiki]
    end

    def default_exclude_patterns
      %w[
        vendor/**/*
        node_modules/**/*
        tmp/**/*
        log/**/*
        coverage/**/*
        .git/**/*
        *.gem
        .bundle/**/*
      ]
    end
  end
end
