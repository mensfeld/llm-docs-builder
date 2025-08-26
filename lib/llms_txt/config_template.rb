# frozen_string_literal: true

# Example configuration file for llms-txt-ruby
# Save this as llms_txt_config.rb in your project root

LlmsTxt.configure do |config|
  # LLM Provider Settings
  config.llm_provider = :claude # :claude, :openai, or :local
  config.api_key = ENV.fetch('ANTHROPIC_API_KEY', nil) # or ENV['OPENAI_API_KEY']
  config.model = 'claude-3-opus-20240229'
  config.temperature = 0.3
  config.max_tokens = 4096

  # Output Settings
  config.output_path = 'llms.txt'
  config.include_optional = true
  config.verbose = true

  # File Analysis Settings
  config.file_analyzers = %i[readme gemspec yard changelog examples docs]

  # File Pattern Settings
  config.exclude_patterns = %w[
    vendor/**/*
    node_modules/**/*
    tmp/**/*
    log/**/*
    coverage/**/*
    .git/**/*
    *.gem
    .bundle/**/*
  ]

  # Auto-detection
  config.auto_detect_docs = true

  # YARD Settings
  config.yard_options = {
    # Additional YARD configuration if needed
  }
end
