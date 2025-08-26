# frozen_string_literal: true

module LlmsTxt
  module Analyzers
    class Changelog < Base
      CHANGELOG_FILES = %w[CHANGELOG.md CHANGELOG CHANGES.md CHANGES NEWS.md NEWS HISTORY.md HISTORY].freeze

      def analyze
        changelog_file = find_changelog
        return {} unless changelog_file

        content = read_file(changelog_file)
        return {} unless content

        {
          path: changelog_file,
          latest_version: extract_latest_version(content),
          recent_changes: extract_recent_changes(content),
          versions: extract_all_versions(content),
          update_frequency: analyze_update_frequency(content)
        }.compact
      end

      private

      def find_changelog
        CHANGELOG_FILES.find { |name| file_exists?(name) }
      end

      def extract_latest_version(content)
        version_pattern = /^##?\s*\[?v?(\d+\.\d+\.\d+[^\]\s]*)\]?/i
        match = content.match(version_pattern)
        return nil unless match

        {
          number: match[1],
          date: extract_version_date(match.post_match),
          summary: extract_version_summary(match.post_match)
        }
      end

      def extract_version_date(content)
        date_patterns = [
          /\((\d{4}-\d{2}-\d{2})\)/,
          /(\d{4}-\d{2}-\d{2})/,
          /(\w+ \d{1,2},? \d{4})/
        ]

        date_patterns.each do |pattern|
          match = content.lines.first(3).join.match(pattern)
          return match[1] if match
        end

        nil
      end

      def extract_version_summary(content)
        lines = content.lines
        summary_lines = []

        lines.each do |line|
          break if line =~ /^##?\s/
          next if line.strip.empty?
          next if line =~ /^\d{4}-\d{2}-\d{2}/

          summary_lines << line.strip if summary_lines.size < 5
        end

        summary_lines.join(' ').strip if summary_lines.any?
      end

      def extract_recent_changes(content, limit = 3)
        changes = []
        current_version = nil
        current_content = []

        content.lines.each do |line|
          if line =~ /^##?\s*\[?v?(\d+\.\d+\.\d+[^\]\s]*)\]?/i
            if current_version && changes.size < limit
              changes << {
                version: current_version,
                content: current_content.join.strip
              }
            end
            current_version = Regexp.last_match(1)
            current_content = []
          elsif current_version
            current_content << line unless line.strip.empty?
          end
        end

        if current_version && changes.size < limit
          changes << {
            version: current_version,
            content: current_content.join.strip
          }
        end

        changes
      end

      def extract_all_versions(content)
        versions = []

        content.scan(/^##?\s*\[?v?(\d+\.\d+\.\d+[^\]\s]*)\]?/i) do |match|
          versions << match[0].strip
        end

        versions
      end

      def analyze_update_frequency(content)
        dates = extract_all_dates(content)
        return nil if dates.size < 2

        intervals = []
        dates.each_cons(2) do |date1, date2|
          interval = (date1 - date2).abs
          intervals << interval
        end

        {
          average_days: (intervals.sum / intervals.size.to_f).round,
          releases_count: dates.size,
          first_release: dates.last,
          latest_release: dates.first
        }
      rescue StandardError
        nil
      end

      def extract_all_dates(content)
        dates = []
        date_pattern = /\((\d{4}-\d{2}-\d{2})\)/

        content.scan(date_pattern) do |match|
          dates << Date.parse(match[0])
        end

        dates.sort.reverse
      rescue StandardError
        []
      end
    end
  end
end
