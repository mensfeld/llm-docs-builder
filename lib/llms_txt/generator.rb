# frozen_string_literal: true

module LlmsTxt
  # Simple generator that creates llms.txt from existing markdown documentation
  #
  # Takes a documentation directory or file and generates a properly formatted llms.txt file by
  # analyzing markdown files, extracting titles and descriptions, and organizing them by priority.
  #
  # @example Generate from docs directory
  #   generator = LlmsTxt::Generator.new('./docs', base_url: 'https://myproject.io')
  #   content = generator.generate
  #
  # @api public
  class Generator
    # @return [String] path to documentation directory or file
    attr_reader :docs_path

    # @return [Hash] generation options
    attr_reader :options

    # Initialize a new generator
    #
    # @param docs_path [String] path to documentation directory or file
    # @param options [Hash] generation options
    # @option options [String] :base_url base URL for expanding relative links
    # @option options [String] :title project title (overrides auto-detection)
    # @option options [String] :description project description (overrides auto-detection)
    # @option options [String] :output output file path for saving
    # @option options [Boolean] :verbose enable verbose output
    def initialize(docs_path, options = {})
      @docs_path = docs_path
      @options = options
    end

    # Generate llms.txt content from documentation
    #
    # Scans documentation files, extracts metadata, prioritizes them, and builds a formatted
    # llms.txt file.
    #
    # @return [String] generated llms.txt content
    def generate
      docs = find_documentation_files

      content = build_llms_txt(docs)

      if output_path = options[:output]
        File.write(output_path, content)
      end

      content
    end

    private

    def find_documentation_files
      return [] unless File.exist?(docs_path)

      if File.file?(docs_path)
        [analyze_file(docs_path)]
      else
        find_markdown_files_in_directory
      end
    end

    def find_markdown_files_in_directory
      files = []

      Find.find(docs_path) do |path|
        next unless File.file?(path)
        next unless path.match?(/\.md$/i)
        next if File.basename(path).start_with?('.')

        files << analyze_file(path)
      end

      files.sort_by { |f| f[:priority] }
    end

    def analyze_file(file_path)
      # Handle single file case differently
      relative_path = if File.file?(docs_path)
                       File.basename(file_path)
                     else
                       Pathname.new(file_path).relative_path_from(Pathname.new(docs_path)).to_s
                     end

      content = File.read(file_path)

      {
        path: relative_path,
        title: extract_title(content, file_path),
        description: extract_description(content),
        priority: calculate_priority(file_path)
      }
    end

    def extract_title(content, file_path)
      # Try to extract title from first # header
      if content.match(/^#\s+(.+)/)
        $1.strip
      else
        # Use filename as fallback
        File.basename(file_path, '.md').gsub(/[_-]/, ' ').split.map(&:capitalize).join(' ')
      end
    end

    def extract_description(content)
      lines = content.lines

      # Skip title line and empty lines
      description_lines = lines.drop_while { |line| line.start_with?('#') || line.strip.empty? }

      # Get first paragraph
      first_paragraph = description_lines.take_while { |line| !line.strip.empty? }

      first_paragraph.join(' ').strip.slice(0, 200)
    end

    def calculate_priority(file_path)
      basename = File.basename(file_path).downcase

      return 1 if basename.start_with?('readme')
      return 2 if basename.include?('getting')
      return 3 if basename.include?('guide')
      return 4 if basename.include?('tutorial')
      return 5 if basename.include?('api')
      return 6 if basename.include?('reference')

      7 # default priority
    end

    def build_llms_txt(docs)
      title = options[:title] || detect_project_title(docs)
      description = options[:description] || detect_project_description(docs)

      content = []
      content << "# #{title}"
      content << ""
      content << "> #{description}" if description
      content << ""

      if docs.any?
        content << "## Documentation"
        content << ""

        docs.each do |doc|
          url = build_url(doc[:path])
          if doc[:description] && !doc[:description].empty?
            content << "- [#{doc[:title]}](#{url}): #{doc[:description]}"
          else
            content << "- [#{doc[:title]}](#{url})"
          end
        end
      end

      content.join("\n") + "\n"
    end

    def detect_project_title(docs)
      readme = docs.find { |doc| doc[:path].downcase.include?('readme') }
      return readme[:title] if readme

      File.basename(File.expand_path('.'))
    end

    def detect_project_description(docs)
      readme = docs.find { |doc| doc[:path].downcase.include?('readme') }
      return readme[:description] if readme&.fetch(:description, nil)

      nil
    end

    def build_url(path)
      if base_url = options[:base_url]
        File.join(base_url, path)
      else
        path
      end
    end
  end
end
