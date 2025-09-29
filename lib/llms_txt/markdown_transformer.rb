# frozen_string_literal: true

module LlmsTxt
  # Transforms markdown files to be AI-friendly
  class MarkdownTransformer
    attr_reader :file_path, :options

    def initialize(file_path, options = {})
      @file_path = file_path
      @options = options
    end

    def transform
      content = File.read(file_path)

      content = expand_relative_links(content) if options[:base_url]
      content = convert_html_urls(content) if options[:convert_urls]

      content
    end

    private

    def expand_relative_links(content)
      base_url = options[:base_url]

      content.gsub(/\[([^\]]+)\]\(([^)]+)\)/) do |match|
        text = $1
        url = $2

        if url.start_with?('http://', 'https://', '//', '#')
          match # Already absolute or anchor
        else
          # Clean up relative path
          clean_url = url.gsub(%r{^\./}, '') # Remove leading './'
          expanded_url = File.join(base_url, clean_url)
          "[#{text}](#{expanded_url})"
        end
      end
    end

    def convert_html_urls(content)
      content.gsub(%r{https?://[^\s<>]+\.html?(?=[)\s]|$)}) do |url|
        url.sub(/\.html?$/, '.md')
      end
    end
  end
end