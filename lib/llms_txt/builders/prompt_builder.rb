# frozen_string_literal: true

module LlmsTxt
  module Builders
    class PromptBuilder
      attr_reader :data, :options

      def initialize(data, options = {})
        @data = data
        @options = options
      end

      def build
        prompt = []

        prompt << system_instruction
        prompt << "\n---\n"
        prompt << project_context
        prompt << "\n---\n"
        prompt << generation_requirements
        prompt << "\n---\n"
        prompt << "Project Data:\n"
        prompt << format_project_data

        prompt.join("\n")
      end

      private

      def system_instruction
        <<~PROMPT
          You are an expert Ruby developer tasked with generating an llms.txt file for a Ruby project.
          The llms.txt file follows a specific format designed to help Large Language Models understand
          and navigate the project effectively.

          Your goal is to create a comprehensive yet concise llms.txt file that provides LLMs with
          the most relevant information about this Ruby project.
        PROMPT
      end

      def project_context
        context = []

        context << "Project Name: #{data.dig(:gemspec, :name) || 'Unknown'}"
        context << "Version: #{data.dig(:gemspec, :version) || '0.0.0'}"
        context << "Summary: #{data.dig(:gemspec, :summary) || 'No summary available'}"

        if (authors = data.dig(:gemspec, :authors))
          context << "Authors: #{Array(authors).join(', ')}"
        end

        if (license = data.dig(:gemspec, :license))
          context << "License: #{license}"
        end

        context.join("\n")
      end

      def generation_requirements
        <<~REQUIREMENTS
          Generate an llms.txt file following these requirements:

          1. Start with an H1 header containing the project name
          2. Include a blockquote with a concise project description (one line, under 200 chars)
          3. Add a "## Documentation" section with relevant documentation links
          4. Add a "## Examples" section if examples are available
          5. Optionally add an "## Optional" section for additional resources

          Format each link as: - [Link Title](URL): Brief description

          Keep descriptions concise and focused on helping LLMs understand the project structure.
          Use relative paths for local files and absolute URLs for external resources.

          The output should be clean markdown without any additional explanations or meta-text.
          Output only the llms.txt content, nothing else.
        REQUIREMENTS
      end

      def format_project_data
        formatted = []

        formatted << format_readme_data if data[:readme]

        formatted << format_gemspec_data if data[:gemspec]

        formatted << format_yard_data if data[:yard]

        formatted << format_docs_data if data[:docs]

        formatted << format_examples_data if data[:examples]

        formatted << format_changelog_data if data[:changelog]

        formatted << format_wiki_data if data[:wiki]

        formatted.compact.join("\n\n")
      end

      def format_readme_data
        return nil unless data[:readme]

        sections = []
        sections << 'README Information:'

        if (title = data.dig(:readme, :sections, :title))
          sections << "  Title: #{title}"
        end

        if (desc = data.dig(:readme, :sections, :description))
          sections << "  Description: #{truncate(desc, 200)}"
        end

        if (docs = data.dig(:readme, :sections, :documentation))
          sections << "  Documentation Links: #{docs.size} found"
        end

        sections.join("\n")
      end

      def format_gemspec_data
        return nil unless data[:gemspec]

        sections = []
        sections << 'Gemspec Information:'
        sections << "  Name: #{data[:gemspec][:name]}"
        sections << "  Version: #{data[:gemspec][:version]}"
        sections << "  Summary: #{data[:gemspec][:summary]}"

        if (metadata = data[:gemspec][:metadata])
          sections << '  Available URIs:'
          metadata.each do |key, value|
            sections << "    #{key}: #{value}" if key.to_s.include?('uri')
          end
        end

        sections.join("\n")
      end

      def format_yard_data
        return nil unless data[:yard]

        sections = []
        sections << 'YARD Documentation:'

        if (stats = data[:yard][:stats])
          sections << "  Documentation Coverage: #{stats[:percentage]}%"
          sections << "  Total Objects: #{stats[:total]}"
        end

        if (api = data[:yard][:api_summary])
          sections << "  Classes: #{api[:classes]}"
          sections << "  Modules: #{api[:modules]}"
          sections << "  Methods: #{api[:methods]}"
        end

        if (examples = data[:yard][:examples])
          sections << "  Code Examples: #{examples.size} found"
        end

        sections.join("\n")
      end

      def format_docs_data
        return nil unless data[:docs]

        sections = []
        sections << 'Documentation Files:'
        sections << "  Total Files: #{data[:docs][:total_files]}"
        sections << "  Total Words: #{data[:docs][:total_words]}"

        if (guides = data[:docs][:guides])
          sections << "  Guides Available: #{guides.size}"
          guides.first(3).each do |guide|
            sections << "    - #{guide[:title]} (#{guide[:type]})"
          end
        end

        sections.join("\n")
      end

      def format_examples_data
        return nil unless data[:examples]

        sections = []
        sections << 'Example Files:'
        sections << "  Total Examples: #{data[:examples][:total_count]}"

        if (categories = data[:examples][:categories])
          sections << '  Categories:'
          categories.each do |category, files|
            sections << "    #{category}: #{files.size} files"
          end
        end

        if (tech = data[:examples][:technologies])
          sections << "  Technologies Used: #{tech.join(', ')}"
        end

        sections.join("\n")
      end

      def format_changelog_data
        return nil unless data[:changelog]

        sections = []
        sections << 'Changelog Information:'

        if (latest = data[:changelog][:latest_version])
          sections << "  Latest Version: #{latest[:number]} (#{latest[:date]})"
        end

        if (freq = data[:changelog][:update_frequency])
          sections << "  Release Frequency: ~#{freq[:average_days]} days"
          sections << "  Total Releases: #{freq[:releases_count]}"
        end

        sections.join("\n")
      end

      def format_wiki_data
        return nil unless data[:wiki]

        sections = []
        sections << 'Wiki Information:'
        sections << "  Total Files: #{data[:wiki][:total_files]}"
        sections << "  Total Words: #{data[:wiki][:total_words]}"

        if (navigation = data[:wiki][:navigation])
          sections << "  Navigation Files: #{navigation.keys.size}"
        end

        if (link_analysis = data[:wiki][:link_analysis])
          sections << "  Internal Links: #{link_analysis[:total_internal_links]}"
          sections << "  Broken Links: #{link_analysis[:broken_links].size}"
        end

        sections.join("\n")
      end

      def truncate(text, max_length)
        return text if text.length <= max_length

        "#{text[0...max_length]}..."
      end
    end
  end
end
