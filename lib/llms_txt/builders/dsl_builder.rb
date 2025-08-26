# frozen_string_literal: true

module LlmsTxt
  module Builders
    # Fluent DSL builder for creating llms.txt content programmatically
    #
    # Provides a chainable interface for building llms.txt files with sections,
    # links, and auto-discovery features. Supports both block-based and fluent 
    # method chaining approaches.
    #
    # @example Basic usage
    #   builder = LlmsTxt::Builders::DslBuilder.new
    #   builder.title('My Project')
    #          .description('A Ruby library')
    #          .documentation { |docs| docs.link('API', 'api.md') }
    #          .build
    #
    # @example With block syntax
    #   content = LlmsTxt.build do |llms|
    #     llms.title 'My Project'
    #     llms.description 'A Ruby library'
    #     llms.documentation do |docs|
    #       docs.link 'API Reference', 'docs/api.md'
    #     end
    #   end.build
    class DslBuilder
      attr_reader :title, :description, :sections

      # Initialize a new DSL builder
      #
      # @return [DslBuilder] new builder instance
      def initialize
        @sections = []
        @title = nil
        @description = nil
      end

      # Sets the project title
      #
      # @param text [String] the project title
      # @return [DslBuilder] self for method chaining
      #
      # @example
      #   builder.title('My Awesome Gem')
      def title(text)
        @title = text
        self
      end

      # Sets the project description
      #
      # @param text [String] the project description
      # @return [DslBuilder] self for method chaining
      #
      # @example
      #   builder.description('A Ruby library for processing data')
      def description(text)
        @description = text
        self
      end

      # Creates a new section with the given name and options
      #
      # @param name [String] the section name (e.g., "Documentation")
      # @param options [Hash] section configuration options
      # @option options [Boolean] :required whether section appears even if empty
      # @yield [section] block for configuring the section
      # @yieldparam section [SectionBuilder] the section builder
      # @return [DslBuilder] self for method chaining
      #
      # @example Create a custom section
      #   builder.section('API Endpoints') do |api|
      #     api.link('Health Check', '/health')
      #     api.link('User API', '/api/users')
      #   end
      def section(name, options = {}, &)
        section_builder = SectionBuilder.new(name, options)
        section_builder.instance_eval(&) if block_given?
        @sections << section_builder
        self
      end

      # Creates a documentation section
      #
      # Convenience method for creating a "Documentation" section.
      #
      # @yield [docs] block for configuring documentation links
      # @yieldparam docs [SectionBuilder] the documentation section builder
      # @return [DslBuilder] self for method chaining
      #
      # @example
      #   builder.documentation do |docs|
      #     docs.link 'API Reference', 'docs/api.md'
      #     docs.link 'Getting Started', 'docs/start.md'
      #   end
      def documentation(&)
        section('Documentation', &)
      end

      # Creates an examples section
      #
      # Convenience method for creating an "Examples" section.
      #
      # @yield [examples] block for configuring example links
      # @yieldparam examples [SectionBuilder] the examples section builder
      # @return [DslBuilder] self for method chaining
      #
      # @example
      #   builder.examples do |ex|
      #     ex.auto_discover_examples
      #     ex.link 'Advanced Usage', 'examples/advanced.rb'
      #   end
      def examples(&)
        section('Examples', &)
      end

      # Creates an optional section
      #
      # Convenience method for creating an "Optional" section with common
      # project links like changelog, license, and homepage.
      #
      # @yield [optional] block for configuring optional links
      # @yieldparam optional [SectionBuilder] the optional section builder
      # @return [DslBuilder] self for method chaining
      #
      # @example
      #   builder.optional do |opt|
      #     opt.changelog
      #     opt.license('MIT')
      #     opt.homepage('https://github.com/user/project')
      #   end
      def optional(&)
        section('Optional', &)
      end

      # Builds the final llms.txt content
      #
      # Generates markdown content following the llms.txt specification.
      # Includes title, description, and all configured sections with their links.
      #
      # @return [String] the generated llms.txt content
      #
      # @example
      #   content = builder.build
      #   File.write('llms.txt', content)
      def build
        content = []

        # Title (required)
        if @title
          content << "# #{@title}"
          content << ''
        end

        # Description (optional but recommended)
        if @description
          content << "> #{@description}"
          content << ''
        end

        # Build sections
        @sections.each do |section|
          section_content = section.build
          content.concat(section_content) unless section_content.empty?
          content << '' unless section_content.empty?
        end

        # Remove trailing empty lines
        content.pop while content.last&.empty?

        content.join("\n")
      end

      # Alias for build method
      #
      # @return [String] the generated llms.txt content
      # @see #build
      def to_s
        build
      end
    end

    # Builder for individual sections within llms.txt files
    #
    # Handles the creation of sections like "Documentation", "Examples", etc.
    # Provides methods for adding links, auto-discovering files, and common
    # shortcuts for standard project links.
    #
    # @example Manual link addition
    #   section.link('API Docs', 'docs/api.md', description: 'Complete API reference')
    #
    # @example Auto-discovery
    #   section.auto_discover_examples('examples/**/*.rb')
    class SectionBuilder
      attr_reader :name, :options, :links, :auto_discover_patterns

      # Initialize a new section builder
      #
      # @param name [String] the section name
      # @param options [Hash] configuration options
      # @option options [Boolean] :required whether section appears even if empty
      def initialize(name, options = {})
        @name = name
        @options = options
        @links = []
        @auto_discover_patterns = []
        @required = options[:required]
      end

      # Adds a link to this section
      #
      # @param title [String] the link title/text
      # @param url [String] the link URL or path
      # @param description [String, nil] optional link description
      # @param metadata [Hash] additional metadata for the link
      # @return [SectionBuilder] self for method chaining
      #
      # @example Simple link
      #   section.link('Getting Started', 'docs/start.md')
      #
      # @example Link with description
      #   section.link('API Reference', 'api.md', description: 'Complete API docs')
      def link(title, url, description: nil, **metadata)
        @links << {
          title: title,
          url: url,
          description: description,
          metadata: metadata
        }
        self
      end

      # Configures auto-discovery of files matching a pattern
      #
      # @param pattern [String] file glob pattern to match
      # @param options [Hash] discovery options
      # @option options [Symbol] :type the type of files being discovered
      # @return [SectionBuilder] self for method chaining
      #
      # @example Discover all markdown files
      #   section.auto_discover('docs/**/*.md', type: :documentation)
      def auto_discover(pattern, options = {})
        @auto_discover_patterns << { pattern: pattern, options: options }
        self
      end

      # Adds a changelog link (Ruby gem shortcut)
      #
      # @param path [String] path to changelog file
      # @param description [String] link description
      # @return [SectionBuilder] self for method chaining
      def changelog(path = 'CHANGELOG.md', description: 'Version history and release notes')
        link('Changelog', path, description: description)
      end

      # Adds a license link (Ruby gem shortcut)
      #
      # @param type [String] license type (e.g., 'MIT', 'Apache')
      # @param path [String] path to license file
      # @param description [String, nil] custom description
      # @return [SectionBuilder] self for method chaining
      def license(type, path = 'LICENSE', description: nil)
        desc = description || type
        link('License', path, description: desc)
      end

      # Adds a homepage link (Ruby gem shortcut)
      #
      # @param url [String] homepage URL
      # @param description [String] link description
      # @return [SectionBuilder] self for method chaining
      def homepage(url, description: 'Project homepage')
        link('Homepage', url, description: description)
      end

      # Adds a contributing guide link (Ruby gem shortcut)
      #
      # @param path [String] path to contributing guide
      # @param description [String] link description
      # @return [SectionBuilder] self for method chaining
      def contributing(path = 'CONTRIBUTING.md', description: 'How to contribute to this project')
        link('Contributing', path, description: description)
      end

      # Auto-discovers example files
      #
      # Convenience method for discovering Ruby example files with intelligent
      # title and description extraction from comments.
      #
      # @param pattern [String] file pattern to match
      # @return [SectionBuilder] self for method chaining
      def auto_discover_examples(pattern = 'examples/**/*.rb')
        auto_discover(pattern, type: :examples)
      end

      # Auto-discovers documentation files
      #
      # Convenience method for discovering markdown documentation files with
      # title extraction from headers and description from content.
      #
      # @param pattern [String] file pattern to match
      # @return [SectionBuilder] self for method chaining
      def auto_discover_docs(pattern = 'docs/**/*.md')
        auto_discover(pattern, type: :documentation)
      end

      def build
        content = []

        # Process auto-discovery first
        process_auto_discoveries

        # Only skip empty sections if not required
        return content if @links.empty? && !@required

        # Section header
        content << "## #{@name}"
        content << ''

        # Links
        @links.each do |link_data|
          link_line = build_link(link_data)
          content << link_line
        end

        content
      end

      private

      def process_auto_discoveries
        @auto_discover_patterns.each do |discovery|
          pattern = discovery[:pattern]
          options = discovery[:options]

          Dir.glob(pattern).each do |file_path|
            next unless File.file?(file_path)

            title, description = extract_file_info(file_path, options)
            next if title.nil?

            @links << {
              title: title,
              url: file_path,
              description: description,
              metadata: { auto_discovered: true, type: options[:type] }
            }
          end
        end
      end

      def extract_file_info(file_path, options)
        case options[:type]
        when :examples
          extract_example_info(file_path)
        when :documentation
          extract_doc_info(file_path)
        else
          extract_generic_info(file_path)
        end
      end

      def extract_example_info(file_path)
        content = File.read(file_path, encoding: 'utf-8')

        # Look for title in comments
        title_match = content.match(/^#\s*(.+?)(?:\n|$)/)
        title = if title_match
                  title_match[1].strip
                else
                  File.basename(file_path, '.*').tr('_', ' ').split.map(&:capitalize).join(' ')
                end

        # Look for description
        description = extract_description_from_comments(content)
        description ||= "Example: #{title}"

        [title, description]
      end

      def extract_doc_info(file_path)
        content = File.read(file_path, encoding: 'utf-8')

        # Look for H1 title
        title_match = content.match(/^#\s+(.+?)(?:\n|$)/)
        title = if title_match
                  title_match[1].strip
                else
                  File.basename(file_path, '.*').tr('_-', ' ').split.map(&:capitalize).join(' ')
                end

        # Look for description (first paragraph after title)
        desc_match = content.match(/^#\s+.+?\n\n(.+?)(?:\n\n|\n#|\z)/m)
        description = desc_match ? desc_match[1].strip.gsub("\n", ' ') : nil
        description = truncate_description(description) if description

        [title, description]
      end

      def extract_generic_info(file_path)
        title = File.basename(file_path, '.*').tr('_-', ' ').split.map(&:capitalize).join(' ')
        [title, nil]
      end

      def extract_description_from_comments(content)
        # Look for multi-line comment block after title
        desc_match = content.match(/^#\s*.+?\n(?:#\s*(.+?)(?:\n#\s*(.+?))*)\n(?:[^#]|\z)/m)
        return nil unless desc_match

        description_lines = content.lines
                                   .drop_while { |line| !line.match(/^#\s*.+/) || line.match(/^#\s*!/) }
                                   .drop(1) # Skip the title line
                                   .take_while { |line| line.match(/^#\s*/) && !line.match(/^#\s*$/) }
                                   .map { |line| line.sub(/^#\s*/, '').strip }
                                   .reject(&:empty?)

        return nil if description_lines.empty?

        truncate_description(description_lines.join(' '))
      end

      def truncate_description(description)
        return nil if description.nil? || description.strip.empty?

        description = description.strip
        description = "#{description[0...97]}..." if description.length > 100
        description
      end

      def build_link(link_data)
        title = link_data[:title]
        url = link_data[:url]
        description = link_data[:description]

        if description
          "- [#{title}](#{url}): #{description}"
        else
          "- [#{title}](#{url})"
        end
      end
    end
  end
end
