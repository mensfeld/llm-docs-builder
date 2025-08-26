# frozen_string_literal: true

module LlmsTxt
  module Analyzers
    class Readme < Base
      README_FILES = %w[README.md README.markdown README.rdoc README README.txt].freeze

      def analyze
        readme_file = find_readme
        return {} unless readme_file

        content = read_file(readme_file)
        return {} unless content

        {
          path: readme_file,
          content: content,
          sections: extract_sections(content),
          metadata: extract_metadata(content)
        }
      end

      private

      def find_readme
        README_FILES.find { |name| file_exists?(name) }
      end

      def extract_sections(content)
        sections = extract_markdown_sections(content)

        {
          title: extract_title(content),
          description: extract_description(sections),
          installation: sections[:installation],
          usage: sections[:usage] || sections[:getting_started],
          examples: sections[:examples],
          documentation: extract_documentation_links(content),
          contributing: sections[:contributing],
          license: sections[:license]
        }.compact
      end

      def extract_title(content)
        first_line = content.lines.first
        return nil unless first_line

        return unless first_line =~ /^#\s+(.+)$/

        Regexp.last_match(1).strip
      end

      def extract_description(sections)
        sections[:description] ||
          sections[:overview] ||
          sections[:introduction] ||
          extract_first_paragraph(sections)
      end

      def extract_first_paragraph(sections)
        content = sections.values.first
        return nil unless content

        paragraphs = content.split("\n\n")
        first = paragraphs.find { |p| p.strip.length > 50 && !p.include?('```') }
        first&.strip
      end

      def extract_documentation_links(content)
        links = []

        content.scan(/\[([^\]]+)\]\(([^)]+)\)/) do |text, url|
          links << { title: text, url: url } if text =~ /doc|guide|api|reference|tutorial/i
        end

        links
      end

      def extract_metadata(content)
        {
          badges: extract_badges(content),
          has_toc: content.include?('## Table of Contents') || content.include?('## TOC'),
          has_examples: content =~ /##?\s*Examples?/i,
          has_api_docs: content =~ /##?\s*API/i,
          word_count: content.split.size
        }
      end

      def extract_badges(content)
        badges = []

        content.scan(/\[!\[([^\]]+)\]\(([^)]+)\)\]\(([^)]+)\)/) do |alt, img, link|
          badges << { alt: alt, image: img, link: link }
        end

        badges
      end
    end
  end
end
