# frozen_string_literal: true

require 'uri'
require 'pathname'

module LlmsTxt
  module Analyzers
    class Wiki < Base
      WIKI_DIRECTORIES = %w[wiki docs doc documentation wiki_docs].freeze
      MARKDOWN_EXTENSIONS = %w[.md .markdown].freeze

      def analyze
        wiki_files = find_wiki_files
        return {} if wiki_files.empty?

        {
          files: analyze_wiki_files(wiki_files),
          structure: build_wiki_structure(wiki_files),
          navigation: extract_navigation(wiki_files),
          total_files: wiki_files.size,
          total_words: calculate_total_words(wiki_files),
          index_file: find_index_file(wiki_files),
          link_analysis: analyze_links(wiki_files)
        }.compact
      end

      private

      def find_wiki_files
        files = []

        WIKI_DIRECTORIES.each do |dir|
          next unless file_exists?(dir)

          MARKDOWN_EXTENSIONS.each do |ext|
            files.concat(find_files("#{dir}/**/*#{ext}"))
          end
        end

        # Also check root level markdown files that might be wiki-like
        MARKDOWN_EXTENSIONS.each do |ext|
          files.concat(find_files("*#{ext}"))
        end

        # Remove common non-wiki files
        files.reject! { |f| f =~ /(README|CHANGELOG|LICENSE|CONTRIBUTING)\.md$/i }

        files.uniq.map { |f| f.gsub("#{project_root}/", '') }
      end

      def analyze_wiki_files(files)
        files.map do |file|
          content = read_file(file)
          next unless content

          {
            path: file,
            title: extract_title(content, file),
            sections: extract_sections(content),
            internal_links: extract_internal_links(content),
            external_links: extract_external_links(content),
            word_count: content.split.size,
            headers: extract_headers(content),
            last_modified: file_last_modified(file)
          }.compact
        end.compact
      end

      def extract_title(content, file)
        # Try to find H1 header first
        first_h1 = content.lines.find { |l| l.start_with?('# ') }
        return first_h1.gsub(/^#\s*/, '').strip if first_h1

        # Fallback to filename
        File.basename(file, '.*').gsub(/[-_]/, ' ').split.map(&:capitalize).join(' ')
      end

      def extract_sections(content)
        sections = {}
        current_section = nil
        current_content = []

        content.lines.each do |line|
          if line =~ /^##\s+(.+)$/
            save_section(sections, current_section, current_content) if current_section
            current_section = Regexp.last_match(1).strip.downcase.gsub(/\s+/, '_').to_sym
            current_content = []
          else
            current_content << line
          end
        end

        save_section(sections, current_section, current_content) if current_section
        sections
      end

      def save_section(sections, name, content)
        return if name.nil? || content.empty?

        sections[name] = content.join.strip
      end

      def extract_internal_links(content)
        links = []

        # Find markdown links
        content.scan(/\[([^\]]+)\]\(([^)]+)\)/) do |text, url|
          next if absolute_url?(url)
          next if url.start_with?('mailto:', 'tel:', 'ftp:')

          links << {
            text: text,
            url: url,
            type: determine_link_type(url)
          }
        end

        links
      end

      def extract_external_links(content)
        links = []

        content.scan(/\[([^\]]+)\]\(([^)]+)\)/) do |text, url|
          next unless absolute_url?(url)

          links << {
            text: text,
            url: url,
            domain: extract_domain(url)
          }
        end

        links
      end

      def extract_headers(content)
        headers = []

        content.scan(/^(#+)\s+(.+)$/) do |hashes, text|
          headers << {
            level: hashes.length,
            text: text.strip,
            anchor: generate_anchor(text.strip)
          }
        end

        headers
      end

      def generate_anchor(text)
        text.downcase
            .gsub(/[^\w\s-]/, '')
            .gsub(/\s+/, '-')
            .gsub(/-+/, '-')
            .strip
      end

      def build_wiki_structure(files)
        structure = {}

        files.each do |file|
          parts = file.split('/')
          current = structure

          parts[0...-1].each do |part|
            current[part] ||= { type: :directory, children: {} }
            current = current[part][:children]
          end

          current[parts.last] = { type: :file, path: file }
        end

        structure
      end

      def extract_navigation(files)
        # Look for index or navigation files
        nav_files = files.select do |f|
          basename = File.basename(f, '.*').downcase
          basename.match?(/^(index|home|nav|navigation|readme)$/)
        end

        navigation = {}

        nav_files.each do |file|
          content = read_file(file)
          next unless content

          nav_links = extract_navigation_links(content)
          navigation[file] = nav_links if nav_links.any?
        end

        navigation
      end

      def extract_navigation_links(content)
        links = []
        in_list = false

        content.lines.each do |line|
          line = line.strip

          # Start of a list
          if line =~ /^[-*]\s+/
            in_list = true
          elsif in_list && line.empty?
            in_list = false
            next
          elsif in_list && !line.start_with?('  ', '-', '*')
            in_list = false
          end

          next unless in_list

          # Extract link from list item
          next unless line =~ /[-*]\s+\[([^\]]+)\]\(([^)]+)\)/

          links << {
            text: Regexp.last_match(1),
            url: Regexp.last_match(2),
            level: count_leading_spaces(line) / 2
          }
        end

        links
      end

      def find_index_file(files)
        index_files = files.select do |f|
          basename = File.basename(f, '.*').downcase
          basename.match?(/^(index|home|readme)$/)
        end

        index_files.first
      end

      def analyze_links(files)
        all_internal_links = []
        broken_links = []

        files.each do |file|
          content = read_file(file)
          next unless content

          internal_links = extract_internal_links(content)
          all_internal_links.concat(internal_links)

          # Check for broken internal links
          internal_links.each do |link|
            target_path = resolve_link_path(file, link[:url])
            broken_links << { file: file, link: link } unless link_exists?(target_path)
          end
        end

        {
          total_internal_links: all_internal_links.size,
          broken_links: broken_links,
          link_patterns: analyze_link_patterns(all_internal_links)
        }
      end

      def resolve_link_path(source_file, link_url)
        return nil if link_url.start_with?('#') # Anchor links

        source_dir = File.dirname(source_file)
        target_path = File.join(project_root, source_dir, link_url)
        File.expand_path(target_path)
      end

      def link_exists?(path)
        return false unless path

        File.exist?(path) || File.exist?("#{path}.md")
      end

      def analyze_link_patterns(links)
        patterns = Hash.new(0)

        links.each do |link|
          if link[:url].end_with?('.md')
            patterns[:markdown_files] += 1
          elsif link[:url].include?('#')
            patterns[:anchor_links] += 1
          elsif link[:url].start_with?('/')
            patterns[:absolute_paths] += 1
          else
            patterns[:relative_paths] += 1
          end
        end

        patterns
      end

      def calculate_total_words(files)
        files.sum do |file|
          content = read_file(file)
          content ? content.split.size : 0
        end
      end

      def file_last_modified(file)
        path = File.join(project_root, file)
        File.mtime(path) if File.exist?(path)
      rescue StandardError
        nil
      end

      def determine_link_type(url)
        return :anchor if url.start_with?('#')
        return :absolute if url.start_with?('/')
        return :relative if url.include?('../')
        return :markdown if url.end_with?('.md')

        :file
      end

      def absolute_url?(url)
        URI.parse(url).absolute?
      rescue URI::InvalidURIError
        false
      end

      def extract_domain(url)
        URI.parse(url).host
      rescue URI::InvalidURIError
        nil
      end

      def count_leading_spaces(line)
        line.match(/^(\s*)/)[1].length
      end
    end
  end
end
