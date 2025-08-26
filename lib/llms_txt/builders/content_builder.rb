# frozen_string_literal: true

module LlmsTxt
  module Builders
    class ContentBuilder
      attr_reader :data, :options

      def initialize(data, options = {})
        @data = data
        @options = options
      end

      def build_template
        sections = []

        sections << build_header
        sections << build_description
        sections << build_documentation_section
        sections << build_examples_section
        sections << build_optional_section if include_optional?

        sections.compact.join("\n\n")
      end

      def build_from_llm(response)
        response
      end

      private

      def build_header
        title = extract_title
        return nil unless title

        "# #{title}"
      end

      def extract_title
        data.dig(:gemspec, :name) ||
          data.dig(:readme, :sections, :title) ||
          File.basename(options[:project_root] || Dir.pwd)
      end

      def build_description
        description = extract_description
        return nil unless description

        "> #{description}"
      end

      def extract_description
        data.dig(:gemspec, :summary) ||
          data.dig(:readme, :sections, :description) ||
          data.dig(:gemspec, :description)
      end

      def build_documentation_section
        links = collect_documentation_links
        return nil if links.empty?

        section = ["## Documentation\n"]

        links.each do |link|
          section << format_link(link)
        end

        section.join("\n")
      end

      def collect_documentation_links
        links = []

        if data[:readme]
          readme_docs = data.dig(:readme, :sections, :documentation) || []
          readme_docs.each do |doc|
            links << doc if doc.is_a?(Hash) && doc[:title] && doc[:url]
          end
        end

        if data[:gemspec]
          if (doc_uri = data.dig(:gemspec, :metadata, :documentation_uri))
            links << { title: 'API Documentation', url: doc_uri, description: 'Complete API reference' }
          end

          if (source_uri = data.dig(:gemspec, :metadata, :source_code_uri))
            links << { title: 'Source Code', url: source_uri, description: 'View the source code on GitHub' }
          end
        end

        if data[:docs]
          guides = data.dig(:docs, :guides) || []
          guides.each do |guide|
            links << {
              title: guide[:title],
              url: guide[:path],
              description: "#{guide[:difficulty].to_s.capitalize} guide (#{guide[:estimated_time]})"
            }
          end
        end

        if data[:wiki]
          wiki_files = data.dig(:wiki, :files) || []
          # Include main wiki index or navigation files
          main_wiki_files = wiki_files.select { |f| f[:title]&.match?(/index|home|navigation|overview/i) }
          main_wiki_files.first(3).each do |wiki_file|
            links << {
              title: wiki_file[:title],
              url: wiki_file[:path],
              description: "Wiki: #{wiki_file[:title]} (#{wiki_file[:word_count]} words)"
            }
          end
        end

        links.uniq { |l| l[:url] }
      end

      def build_examples_section
        examples = collect_examples
        return nil if examples.empty?

        section = ["## Examples\n"]

        examples.each do |example|
          section << format_link(example)
        end

        section.join("\n")
      end

      def collect_examples
        examples = []

        if data[:examples]
          example_files = data.dig(:examples, :files) || []
          example_files.first(5).each do |file|
            examples << {
              title: file[:title] || file[:name],
              url: file[:path],
              description: file[:description] || "Example: #{file[:name]}"
            }
          end
        end

        if data[:yard]
          yard_examples = data.dig(:yard, :examples) || []
          yard_examples.first(3).each do |ex|
            examples << {
              title: "#{ex[:object]} Example",
              url: '#',
              description: ex[:title] || 'Code example from documentation'
            }
          end
        end

        examples
      end

      def build_optional_section
        return nil unless include_optional?

        links = collect_optional_links
        return nil if links.empty?

        section = ["## Optional\n"]

        links.each do |link|
          section << format_link(link)
        end

        section.join("\n")
      end

      def collect_optional_links
        links = []

        if data[:changelog]
          links << {
            title: 'Changelog',
            url: data.dig(:changelog, :path) || 'CHANGELOG.md',
            description: 'Version history and release notes'
          }
        end

        if data.dig(:readme, :sections, :contributing)
          links << {
            title: 'Contributing Guide',
            url: 'CONTRIBUTING.md',
            description: 'How to contribute to this project'
          }
        end

        if data.dig(:readme, :sections, :license)
          links << {
            title: 'License',
            url: 'LICENSE',
            description: data.dig(:gemspec, :license) || 'License information'
          }
        end

        if (homepage = data.dig(:gemspec, :homepage))
          links << {
            title: 'Project Homepage',
            url: homepage,
            description: 'Main project website'
          }
        end

        links
      end

      def format_link(link)
        base = "- [#{link[:title]}](#{link[:url]})"

        if link[:description] && !link[:description].empty?
          "#{base}: #{link[:description]}"
        else
          base
        end
      end

      def include_optional?
        options[:include_optional] != false &&
          LlmsTxt.configuration.include_optional != false
      end
    end
  end
end
