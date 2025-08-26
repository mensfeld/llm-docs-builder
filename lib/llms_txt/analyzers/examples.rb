# frozen_string_literal: true

module LlmsTxt
  module Analyzers
    class Examples < Base
      EXAMPLE_DIRECTORIES = %w[examples example samples demo].freeze
      EXAMPLE_FILE_PATTERNS = %w[*_example.rb *_sample.rb *_demo.rb example_*.rb sample_*.rb demo_*.rb].freeze

      def analyze
        examples = find_examples
        return {} if examples.empty?

        {
          files: examples.map { |file| analyze_example_file(file) },
          categories: categorize_examples(examples),
          total_count: examples.size,
          total_lines: count_total_lines(examples),
          technologies: detect_technologies(examples)
        }.compact
      end

      private

      def find_examples
        examples = []

        EXAMPLE_DIRECTORIES.each do |dir|
          next unless file_exists?(dir)

          examples.concat(find_files("#{dir}/**/*.rb"))
        end

        EXAMPLE_FILE_PATTERNS.each do |pattern|
          examples.concat(find_files(pattern))
          examples.concat(find_files("spec/#{pattern}"))
          examples.concat(find_files("test/#{pattern}"))
        end

        examples.uniq.map { |f| f.gsub("#{project_root}/", '') }
      end

      def analyze_example_file(file)
        content = read_file(file)
        return nil unless content

        {
          path: file,
          name: File.basename(file, '.*'),
          title: extract_title_from_file(content),
          description: extract_description_from_file(content),
          dependencies: extract_required_files(content),
          methods_demonstrated: extract_demonstrated_methods(content),
          lines_of_code: content.lines.reject { |l| l.strip.empty? || l.strip.start_with?('#') }.size,
          has_comments: content.include?('#'),
          complexity: estimate_complexity(content)
        }.compact
      end

      def extract_title_from_file(content)
        first_comment = content.lines.find do |l|
          l.strip.start_with?('#') && !l.include?('#!/') && !l.include?('frozen_string_literal')
        end
        return nil unless first_comment

        title = first_comment.gsub(/^#\s*/, '').strip
        title.empty? ? nil : title
      end

      def extract_description_from_file(content)
        comments = []
        in_header = true

        content.lines.each do |line|
          if in_header && line.strip.start_with?('#')
            comments << line.gsub(/^#\s*/, '').strip
          elsif !line.strip.empty?
            in_header = false
            break
          end
        end

        comments.join(' ') if comments.any?
      end

      def extract_required_files(content)
        requires = []

        content.scan(/require(?:_relative)?\s+['"]([^'"]+)['"]/) do |match|
          requires << match[0]
        end

        requires.uniq
      end

      def extract_demonstrated_methods(content)
        methods = []

        content.scan(/(\w+)\.(\w+)/) do |obj, method|
          methods << "#{obj}.#{method}"
        end

        content.scan(/(\w+)#(\w+)/) do |obj, method|
          methods << "#{obj}##{method}"
        end

        methods.uniq.grep(/[A-Z]/)
      end

      def categorize_examples(example_files)
        categories = Hash.new { |h, k| h[k] = [] }

        example_files.each do |file|
          category = determine_category(file)
          categories[category] << file
        end

        categories
      end

      def determine_category(file)
        case file
        when /basic|simple|getting_started|introduction|hello/i
          :basic
        when /advanced|complex|expert/i
          :advanced
        when /api|rest|http|client/i
          :api
        when /database|db|orm|active_record|sql/i
          :database
        when /test|spec|rspec|minitest/i
          :testing
        when /config|configuration|setup/i
          :configuration
        else
          :general
        end
      end

      def count_total_lines(files)
        files.sum do |file|
          content = read_file(file)
          content ? content.lines.size : 0
        end
      end

      def detect_technologies(files)
        tech = Set.new

        files.each do |file|
          content = read_file(file)
          next unless content

          tech << 'Rails' if content.include?('Rails') || content.include?('ActiveRecord')
          tech << 'RSpec' if content.include?('RSpec') || content.include?('describe')
          tech << 'Sinatra' if content.include?('Sinatra')
          tech << 'REST API' if content =~ /Net::HTTP|RestClient|Faraday/
          tech << 'Database' if content =~ /ActiveRecord|Sequel|MongoDB/
          tech << 'Redis' if content.include?('Redis')
          tech << 'Sidekiq' if content.include?('Sidekiq')
        end

        tech.to_a.sort
      end

      def estimate_complexity(content)
        score = 0

        score += content.scan(/class\s+\w+/).size * 3
        score += content.scan(/module\s+\w+/).size * 2
        score += content.scan(/def\s+\w+/).size
        score += content.scan(/if|unless|case|while|until|for/).size
        score += content.scan(/rescue|ensure|retry/).size * 2

        case score
        when 0..5 then 'simple'
        when 6..15 then 'moderate'
        else 'complex'
        end
      end
    end
  end
end
