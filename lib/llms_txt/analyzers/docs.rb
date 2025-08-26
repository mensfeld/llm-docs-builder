# frozen_string_literal: true

module LlmsTxt
  module Analyzers
    class Docs < Base
      DOC_DIRECTORIES = %w[docs doc documentation guides wiki].freeze
      DOC_EXTENSIONS = %w[.md .markdown .rdoc .txt .adoc .rst].freeze

      def analyze
        doc_files = find_documentation_files
        return {} if doc_files.empty?

        {
          files: analyze_doc_files(doc_files),
          structure: analyze_doc_structure(doc_files),
          guides: extract_guides(doc_files),
          api_docs: find_api_documentation(doc_files),
          total_files: doc_files.size,
          total_words: calculate_total_words(doc_files)
        }.compact
      end

      private

      def find_documentation_files
        files = []

        DOC_DIRECTORIES.each do |dir|
          next unless file_exists?(dir)

          DOC_EXTENSIONS.each do |ext|
            files.concat(find_files("#{dir}/**/*#{ext}"))
          end
        end

        DOC_EXTENSIONS.each do |ext|
          files.concat(find_files("*#{ext}"))
        end

        files.uniq.map { |f| f.gsub("#{project_root}/", '') }
             .grep_v(/README|CHANGELOG|LICENSE|CONTRIBUTING/i)
      end

      def analyze_doc_files(files)
        files.map do |file|
          content = read_file(file)
          next unless content

          {
            path: file,
            title: extract_doc_title(content, file),
            type: determine_doc_type(file, content),
            sections: extract_doc_sections(content),
            word_count: content.split.size,
            has_code_examples: content.include?('```'),
            has_images: content.scan(/!\[.*?\]\(.*?\)/).any?,
            last_modified: File.mtime(File.join(project_root, file))
          }.compact
        end.compact
      end

      def extract_doc_title(content, file)
        first_heading = content.lines.find { |l| l.start_with?('#') }

        if first_heading
          first_heading.gsub(/^#+\s*/, '').strip
        else
          File.basename(file, '.*').gsub(/[-_]/, ' ').capitalize
        end
      end

      def determine_doc_type(file, content)
        case file.downcase
        when /api/
          :api
        when /guide|tutorial|getting.?started|quickstart/
          :guide
        when /reference/
          :reference
        when /faq|questions/
          :faq
        when /example|sample/
          :examples
        when /config|configuration/
          :configuration
        when /architecture|design/
          :architecture
        else
          analyze_content_type(content)
        end
      end

      def analyze_content_type(content)
        return :api if content =~ /##?\s*(Methods?|Parameters?|Returns?|Endpoints?)/i
        return :guide if content =~ /##?\s*(Getting Started|Installation|Setup|Tutorial)/i
        return :reference if content =~ /##?\s*(Reference|Specification|Schema)/i

        :general
      end

      def extract_doc_sections(content)
        sections = []

        content.scan(/^##?\s+(.+)$/) do |match|
          sections << match[0].strip
        end

        sections
      end

      def analyze_doc_structure(files)
        structure = {}

        files.each do |file|
          parts = file.split('/')
          current = structure

          parts[0...-1].each do |part|
            current[part] ||= {}
            current = current[part]
          end

          current[parts.last] = :file
        end

        structure
      end

      def extract_guides(files)
        guides = []

        files.each do |file|
          next unless file =~ /guide|tutorial|getting.?started|quickstart/i

          content = read_file(file)
          next unless content

          guides << {
            path: file,
            title: extract_doc_title(content, file),
            type: categorize_guide(file, content),
            difficulty: estimate_difficulty(content),
            estimated_time: estimate_reading_time(content)
          }
        end

        guides.sort_by { |g| guide_priority(g[:type]) }
      end

      def categorize_guide(file, content)
        return :getting_started if file =~ /getting.?started|quickstart/i
        return :installation if file =~ /install|setup/i
        return :tutorial if file =~ /tutorial/i
        return :advanced if content =~ /advanced|expert/i

        :general
      end

      def estimate_difficulty(content)
        complexity_indicators = {
          beginner: /basic|simple|introduction|getting started|first/i,
          intermediate: /intermediate|moderate|typical|common/i,
          advanced: /advanced|complex|expert|deep dive/i
        }

        complexity_indicators.each do |level, pattern|
          return level if content =~ pattern
        end

        :intermediate
      end

      def estimate_reading_time(content)
        words = content.split.size
        minutes = (words / 200.0).ceil
        "#{minutes} min"
      end

      def guide_priority(type)
        priorities = {
          getting_started: 1,
          installation: 2,
          tutorial: 3,
          general: 4,
          advanced: 5
        }

        priorities[type] || 99
      end

      def find_api_documentation(files)
        api_docs = files.grep(/api|reference/i)

        api_docs.map do |file|
          content = read_file(file)
          next unless content

          {
            path: file,
            title: extract_doc_title(content, file),
            endpoints: extract_endpoints(content),
            methods: extract_api_methods(content)
          }
        end.compact
      end

      def extract_endpoints(content)
        endpoints = []

        content.scan(/`(GET|POST|PUT|DELETE|PATCH)\s+([^`]+)`/) do |method, path|
          endpoints << { method: method, path: path }
        end

        endpoints
      end

      def extract_api_methods(content)
        methods = []

        content.scan(/^###?\s+`?(\w+(?:\.\w+|\#\w+))`?/) do |match|
          methods << match[0] if match[0] =~ /[.#]/
        end

        methods.uniq
      end

      def calculate_total_words(files)
        files.sum do |file|
          content = read_file(file)
          content ? content.split.size : 0
        end
      end
    end
  end
end
