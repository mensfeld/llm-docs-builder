# frozen_string_literal: true

module LlmDocsBuilder
  # Simple generator that creates llms.txt from existing markdown documentation
  #
  # Takes a documentation directory or file and generates a properly formatted llms.txt file by
  # analyzing markdown files, extracting titles and descriptions, and organizing them by priority.
  #
  # @example Generate from docs directory
  #   generator = LlmDocsBuilder::Generator.new('./docs', base_url: 'https://myproject.io')
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

      if (output_path = options[:output])
        File.write(output_path, content)
      end

      content
    end

    private

    # Locates and analyzes documentation files from docs_path
    #
    # Handles both single file and directory paths
    #
    # @return [Array<Hash>] array of analyzed file metadata
    def find_documentation_files
      return [] unless File.exist?(docs_path)

      if File.file?(docs_path)
        [analyze_file(docs_path)]
      else
        find_markdown_files_in_directory
      end
    end

    # Recursively finds and analyzes markdown files in directory
    #
    # Sorts by priority (README, guides, etc.) and skips hidden files
    #
    # @return [Array<Hash>] sorted array of analyzed file metadata
    def find_markdown_files_in_directory
      files = []

      Find.find(docs_path) do |path|
        next unless File.file?(path)
        next unless path.match?(/\.md$/i)
        next if File.basename(path).start_with?('.')
        next if should_exclude?(path)

        files << analyze_file(path)
      end

      files.sort_by { |f| f[:priority] }
    end

    # Extracts metadata from a documentation file
    #
    # Analyzes file content to extract title, description, priority, and optional metadata
    #
    # @param file_path [String] path to file to analyze
    # @return [Hash] file metadata with :path, :title, :description, :priority, :tokens, :updated
    def analyze_file(file_path)
      # Handle single file case differently
      relative_path = if File.file?(docs_path)
                        File.basename(file_path)
                      else
                        Pathname.new(file_path).relative_path_from(Pathname.new(docs_path)).to_s
                      end

      content = File.read(file_path)

      metadata = {
        path: relative_path,
        title: extract_title(content, file_path),
        description: extract_description(content),
        priority: calculate_priority(file_path)
      }

      # Add optional enhanced metadata
      if options[:include_metadata]
        # Calculate token count from transformed content if any transformations are enabled
        if options[:include_tokens]
          token_content = has_transformations? ? apply_transformations(content, file_path) : content
          metadata[:tokens] = TokenEstimator.estimate(token_content)
        end

        metadata[:updated] = File.mtime(file_path).strftime('%Y-%m-%d') if options[:include_timestamps]

        # Calculate compression ratio if transformation is enabled
        if options[:calculate_compression]
          transformed = apply_transformations(content, file_path)
          original_tokens = TokenEstimator.estimate(content)
          transformed_tokens = TokenEstimator.estimate(transformed)
          metadata[:compression] = (transformed_tokens.to_f / original_tokens).round(2)
        end
      end

      metadata
    end

    # Extracts title from file content or generates from filename
    #
    # Prefers first H1 header, falls back to formatted filename
    #
    # @param content [String] file content
    # @param file_path [String] path to file
    # @return [String] extracted or generated title
    def extract_title(content, file_path)
      # Try to extract title from first # header
      if content.match(/^#\s+(.+)/)
        ::Regexp.last_match(1).strip
      else
        # Use filename as fallback
        File.basename(file_path, '.md').gsub(/[_-]/, ' ').split.map(&:capitalize).join(' ')
      end
    end

    # Extracts description from file content
    #
    # Takes first paragraph after title, truncated to 200 characters
    #
    # @param content [String] file content
    # @return [String] extracted description
    def extract_description(content)
      lines = content.lines

      # Skip title line and empty lines
      description_lines = lines.drop_while { |line| line.start_with?('#') || line.strip.empty? }

      # Get first paragraph
      first_paragraph = description_lines.take_while { |line| !line.strip.empty? }

      first_paragraph.join(' ').strip.slice(0, 200)
    end

    # Assigns priority to file based on filename patterns
    #
    # README gets highest priority, followed by guides, tutorials, API docs
    #
    # @param file_path [String] path to file
    # @return [Integer] priority value (1-7, lower is higher priority)
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

    # Applies transformations to content for compression ratio calculation
    #
    # @param content [String] original content
    # @param file_path [String] path to file
    # @return [String] transformed content
    def apply_transformations(content, file_path)
      transformer = MarkdownTransformer.new(file_path, options)

      # Read file again through transformer to get transformed version
      transformer.transform
    rescue StandardError
      # If transformation fails, return original content
      content
    end

    # Constructs llms.txt content from analyzed documentation files
    #
    # Combines title, description, and documentation links into formatted output
    #
    # @param docs [Array<Hash>] analyzed file metadata
    # @return [String] formatted llms.txt content
    def build_llms_txt(docs)
      title = options[:title] || detect_project_title(docs)
      description = options[:description] || detect_project_description(docs)

      content = []
      content << "# #{title}"
      content << ''
      content << "> #{description}" if description
      content << ''

      if docs.any?
        content << '## Documentation'
        content << ''

        docs.each do |doc|
          url = build_url(doc[:path])
          line = if doc[:description] && !doc[:description].empty?
                   "- [#{doc[:title]}](#{url}): #{doc[:description]}"
                 else
                   "- [#{doc[:title]}](#{url})"
                 end

          # Append metadata if enabled
          if options[:include_metadata]
            metadata_parts = []
            metadata_parts << "tokens:#{doc[:tokens]}" if doc[:tokens]
            metadata_parts << "compression:#{doc[:compression]}" if doc[:compression]
            metadata_parts << "updated:#{doc[:updated]}" if doc[:updated]
            metadata_parts << priority_label(doc[:priority]) if options[:include_priority]

            line += " #{metadata_parts.join(' ')}" unless metadata_parts.empty?
          end

          content << line
        end
      end

      "#{content.join("\n")}\n"
    end

    # Attempts to detect project title from README or directory name
    #
    # @param docs [Array<Hash>] analyzed file metadata
    # @return [String] detected project title
    def detect_project_title(docs)
      readme = docs.find { |doc| doc[:path].downcase.include?('readme') }
      return readme[:title] if readme

      File.basename(File.expand_path('.'))
    end

    # Attempts to extract project description from README
    #
    # @param docs [Array<Hash>] analyzed file metadata
    # @return [String, nil] detected project description or nil
    def detect_project_description(docs)
      readme = docs.find { |doc| doc[:path].downcase.include?('readme') }
      return readme[:description] if readme&.fetch(:description, nil)

      nil
    end

    # Constructs full URL from path using base_url option if provided
    #
    # @param path [String] relative path to file
    # @return [String] full URL or relative path
    def build_url(path)
      if (base_url = options[:base_url])
        File.join(base_url, path)
      else
        path
      end
    end

    # Converts numeric priority to human-readable label
    #
    # @param priority [Integer] priority value (1-7)
    # @return [String] priority label (high, medium, low)
    def priority_label(priority)
      case priority
      when 1..2
        'priority:high'
      when 3..5
        'priority:medium'
      when 6..7
        'priority:low'
      end
    end

    # Tests if file matches any exclusion pattern from options
    #
    # Uses File.fnmatch with pathname and dotmatch flags.
    # Checks against both absolute path and relative path from docs_path.
    #
    # @param file_path [String] path to check
    # @return [Boolean] true if file should be excluded
    def should_exclude?(file_path)
      excludes = Array(options[:excludes])
      return false if excludes.empty?

      # Get relative path from docs_path for matching
      relative_path = if File.directory?(docs_path)
                        Pathname.new(file_path).relative_path_from(Pathname.new(docs_path)).to_s
                      else
                        File.basename(file_path)
                      end

      excludes.any? do |pattern|
        # Check both absolute and relative paths
        File.fnmatch(pattern, file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH) ||
          File.fnmatch(pattern, relative_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
      end
    end

    # Checks if any transformation options are enabled
    #
    # @return [Boolean] true if any transformation option is enabled
    def has_transformations?
      [
        :remove_comments,
        :normalize_whitespace,
        :remove_badges,
        :remove_frontmatter,
        :remove_code_examples,
        :remove_images,
        :simplify_links,
        :remove_blockquotes,
        :remove_stopwords,
        :remove_duplicates
      ].any? { |opt| options[opt] }
    end
  end
end
