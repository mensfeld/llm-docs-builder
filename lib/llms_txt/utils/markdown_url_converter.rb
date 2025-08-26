# frozen_string_literal: true

require 'uri'
require 'pathname'

module LlmsTxt
  module Utils
    # Converts HTML URLs to markdown-friendly URLs in link references
    # Inspired by the Karafka deployment script
    class MarkdownUrlConverter
      attr_reader :file_path, :content

      def initialize(file_path)
        @file_path = Pathname.new(file_path)
        @content = File.read(@file_path, encoding: 'utf-8')
      end

      def convert_links
        @content.gsub(/\[([^\]]+)\]\(([^)]+?)(?:\s+"([^"]+)")?\)/) do |match|
          link_text = Regexp.last_match(1)
          link_url = Regexp.last_match(2)
          title = Regexp.last_match(3)

          if should_convert_url?(link_url)
            converted_url = convert_url(link_url)
            title ? "[#{link_text}](#{converted_url} \"#{title}\")" : "[#{link_text}](#{converted_url})"
          else
            match
          end
        end
      end

      def to_s
        convert_links
      end

      private

      def convert_url(url)
        uri = URI.parse(url)

        # Extract path and fragment (anchor)
        path = uri.path
        fragment = uri.fragment

        # Handle trailing slash - convert to .md
        if path.end_with?('/')
          path = "#{path.chomp('/')}.md"
        else
          # Add .md if it doesn't already have an extension
          path += '.md' unless path.match?(/\.\w+$/)
        end

        # Rebuild URL
        new_url = "#{uri.scheme}://#{uri.host}"
        new_url += ":#{uri.port}" if uri.port && uri.port != uri.default_port
        new_url += path
        new_url += "##{fragment}" if fragment

        new_url
      end

      def should_convert_url?(url)
        return false unless url.start_with?('https://', 'http://')

        # Only convert URLs that look like documentation sites
        documentation_domains = %w[
          github.io
          readthedocs.io
          gitbook.io
          notion.site
        ]

        uri = URI.parse(url)
        domain = uri.host.to_s.downcase

        # Check if it's a documentation domain or has docs-like patterns
        documentation_domains.any? { |doc_domain| domain.include?(doc_domain) } ||
          domain.include?('docs') ||
          uri.path.include?('/docs/') ||
          uri.path.include?('/wiki/')
      rescue URI::InvalidURIError
        false
      end
    end
  end
end
