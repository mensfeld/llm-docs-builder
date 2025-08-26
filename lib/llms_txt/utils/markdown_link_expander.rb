# frozen_string_literal: true

require 'uri'
require 'pathname'

module LlmsTxt
  module Utils
    # Converts local reference links to absolute URLs for LLM consumption
    # Inspired by the Karafka deployment script
    class MarkdownLinkExpander
      attr_reader :file_path, :site_url, :content

      def initialize(file_path, site_url = nil)
        @file_path = Pathname.new(file_path)
        @site_url = site_url&.chomp('/')
        @content = File.read(@file_path, encoding: 'utf-8')
      end

      def expand_links
        return @content unless @site_url

        @content.gsub(/\[([^\]]+)\]\(([^)]+?)(?:\s+"([^"]+)")?\)/) do |match|
          link_text = Regexp.last_match(1)
          link_url = Regexp.last_match(2)
          title = Regexp.last_match(3)

          if absolute_url?(link_url)
            match
          else
            expanded_url = expand_url(link_url)
            title ? "[#{link_text}](#{expanded_url} \"#{title}\")" : "[#{link_text}](#{expanded_url})"
          end
        end
      end

      def to_s
        expand_links
      end

      private

      def expand_url(link_url)
        # Handle anchor links (fragments)
        return get_page_url + link_url if link_url.start_with?('#')

        # Handle absolute paths from root
        return @site_url + link_url if link_url.start_with?('/')

        # Handle relative paths
        target_path = (@file_path.dirname + link_url).cleanpath
        docs_dir = find_docs_dir

        begin
          rel_to_docs = target_path.relative_path_from(docs_dir)
          url_path = rel_to_docs.to_s.gsub('\\', '/')
          url_path = '' if url_path == '.'

          URI.join("#{@site_url}/", url_path).to_s
        rescue ArgumentError
          # If we can't resolve the path, return the original
          link_url
        end
      end

      def get_page_url
        docs_dir = find_docs_dir
        rel_path = @file_path.relative_path_from(docs_dir)
        url_path = rel_path.to_s.gsub('\\', '/')
        url_path = '' if url_path == '.'

        URI.join("#{@site_url}/", url_path).to_s
      end

      def find_docs_dir
        current = @file_path.dirname

        # Look for common documentation indicators
        while current != current.parent
          return current if current.join('mkdocs.yml').exist?
          return current if current.join('_config.yml').exist? # Jekyll
          return current if current.join('docusaurus.config.js').exist? # Docusaurus
          return current if current.basename.to_s.match?(/^(docs?|wiki|documentation)$/i)

          current = current.parent
        end

        # Fallback to file's directory
        @file_path.dirname
      end

      def absolute_url?(url)
        URI.parse(url).absolute?
      rescue URI::InvalidURIError
        false
      end
    end
  end
end
