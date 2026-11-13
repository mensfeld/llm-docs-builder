# frozen_string_literal: true

module LlmDocsBuilder
  # Finds the source markdown files in a documentation directory
  #
  # Shared by `generate` and `bulk-transform` so both pick the same files: hidden directories
  # are pruned unless `include_hidden` is set, hidden files and bulk-transformed files (ending
  # with the suffix, e.g. README.llm.md) are skipped, and files matching `excludes` are left out.
  #
  # @api private
  class MarkdownFinder
    # Flags used for every exclude pattern match
    FNMATCH_FLAGS = File::FNM_PATHNAME | File::FNM_DOTMATCH
    private_constant :FNMATCH_FLAGS

    # Matches a path whose last component starts with a dot
    HIDDEN_PATH_PATTERN = %r{(?:\A|/)\.[^/]*\z}
    private_constant :HIDDEN_PATH_PATTERN

    # @return [String] path to documentation directory
    attr_reader :docs_path

    # @return [Hash] finder options
    attr_reader :options

    # Initialize a new finder
    #
    # @param docs_path [String] path to documentation directory
    # @param options [Hash] finder options
    # @option options [String] :suffix suffix of bulk-transformed files to skip (default: '.llm')
    # @option options [Array<String>] :excludes glob patterns for files to exclude
    # @option options [Boolean] :include_hidden include files in hidden directories
    def initialize(docs_path, options = {})
      @docs_path = docs_path
      @options = options
      @docs_prefix = docs_path.end_with?('/') ? docs_path : "#{docs_path}/"
      @exclude_patterns = Array(options[:excludes]).map { |pattern| normalize_pattern(pattern) }
    end

    # Recursively finds the source markdown files in docs_path
    #
    # @return [Array<String>] paths to markdown files, in directory traversal order
    def files
      files = []
      output_ending = "#{options.fetch(:suffix, '.llm')}.md".downcase

      Find.find(docs_path) do |path|
        if hidden_directory?(path)
          Find.prune
          next
        end

        next unless File.file?(path)
        next unless path.match?(/\.md$/i)
        next if path.match?(HIDDEN_PATH_PATTERN)
        next if output_ending != '.md' && path.downcase.end_with?(output_ending)
        next if excluded?(path)

        files << path
      end

      files
    end

    # Tests if file matches any exclusion pattern from options
    #
    # Checks both the given path and the path relative to docs_path. A trailing `/**` matches
    # files at any depth below the directory.
    #
    # @param file_path [String] path to check
    # @return [Boolean] true if file should be excluded
    def excluded?(file_path)
      return false if @exclude_patterns.empty?

      relative = relative_path(file_path)

      @exclude_patterns.any? do |pattern|
        File.fnmatch(pattern, file_path, FNMATCH_FLAGS) || File.fnmatch(pattern, relative, FNMATCH_FLAGS)
      end
    end

    private

    # Converts an exclude pattern into the fnmatch pattern that implements it
    #
    # @param pattern [String] exclude pattern from options
    # @return [String] fnmatch pattern
    def normalize_pattern(pattern)
      # fnmatch requires /** to be followed by at least one component
      pattern.end_with?('/**') ? "#{pattern}/*" : pattern
    end

    # Tests if path is a hidden directory to skip
    #
    # The root docs_path itself is never skipped (even if it's ".")
    #
    # @param path [String] path to check
    # @return [Boolean] true if path is a hidden directory and include_hidden is not set
    def hidden_directory?(path)
      return false if options[:include_hidden] || path == docs_path

      path.match?(HIDDEN_PATH_PATTERN) && File.directory?(path)
    end

    # Computes the path of a file relative to docs_path
    #
    # Paths from Find.find start with docs_path, so the prefix is stripped without Pathname.
    #
    # @param file_path [String] path to a file inside docs_path
    # @return [String] relative path, or the basename if it can't be made relative
    def relative_path(file_path)
      return file_path.delete_prefix(@docs_prefix) if file_path.start_with?(@docs_prefix)

      @expanded_docs_path ||= Pathname.new(File.expand_path(docs_path))
      Pathname.new(File.expand_path(file_path)).relative_path_from(@expanded_docs_path).to_s
    rescue ArgumentError
      File.basename(file_path)
    end
  end
end
