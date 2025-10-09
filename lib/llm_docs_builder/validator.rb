# frozen_string_literal: true

module LlmDocsBuilder
  # Validates llms.txt content against the llms.txt specification
  #
  # Ensures that llms.txt content follows proper formatting rules including:
  # - Required H1 title header
  # - Optional description blockquote
  # - Proper section ordering (Documentation, Examples, Optional)
  # - Valid markdown syntax and link formats
  # - File size and line length limits
  #
  # @example Validate llms.txt content
  #   validator = LlmDocsBuilder::Validator.new(content)
  #   validator.valid? # => true or false
  #   validator.errors # => Array of error messages
  #
  # @api public
  class Validator
    # @return [String] the llms.txt content being validated
    attr_reader :content

    # @return [Array<String>] array of validation error messages
    attr_reader :errors

    # Required sections that must appear in llms.txt
    REQUIRED_SECTIONS = ['# '].freeze

    # Optional sections that may appear in llms.txt
    OPTIONAL_SECTIONS = ['> ', '## Documentation', '## Examples', '## Optional'].freeze

    # Maximum length for a single line in characters
    MAX_LINE_LENGTH = 120

    # Maximum file size in bytes
    MAX_FILE_SIZE = 50_000

    # Initialize a new validator
    #
    # @param content [String] the llms.txt content to validate
    def initialize(content)
      @content = content
      @errors = []
    end

    # Check if content is valid
    #
    # Runs all validation checks and returns whether the content is valid.
    # Use {#errors} to access validation error messages.
    #
    # @return [Boolean] true if content is valid, false otherwise
    def valid?
      validate!
      errors.empty?
    end

    # Validate content and return result
    #
    # Runs all validation checks, populates {#errors} array, and returns whether
    # the content is valid.
    #
    # @return [Boolean] true if content is valid, false otherwise
    def validate!
      @errors = []

      validate_required_sections
      validate_structure
      validate_markdown_syntax
      validate_links
      validate_file_size

      errors.empty?
    end

    private

    # Checks for required H1 title header and validates title length
    #
    # Adds errors if title is missing or exceeds 80 characters
    def validate_required_sections
      lines = content.lines

      errors << 'Missing required H1 title (must start with "# ")' unless lines.first&.start_with?('# ')

      return unless lines.first&.strip&.length.to_i > 80

      errors << 'Title is too long (max 80 characters)'
    end

    # Validates H1 uniqueness, description length, and section ordering
    #
    # Ensures only one H1, description under 200 chars, and proper section order
    def validate_structure
      lines = content.lines
      h1_count = lines.count { |line| line.start_with?('# ') }

      errors << 'Multiple H1 headers found (only one allowed)' if h1_count > 1

      if lines[1]&.start_with?('> ') && lines[1].strip.length > 200
        errors << 'Description blockquote is too long (max 200 characters)'
      end

      validate_section_order
    end

    # Verifies sections appear in correct order: Documentation, Examples, Optional
    #
    # Detects out-of-order sections and adds validation errors
    def validate_section_order
      sections = content.scan(/^## (.+)$/).flatten
      expected_order = %w[Documentation Examples Optional]

      current_index = -1
      sections.each do |section|
        index = expected_order.index(section)
        next unless index

        errors << "Section '#{section}' is out of order" if index < current_index
        current_index = index
      end
    end

    # Validates markdown syntax including links, lists, and headers
    #
    # Delegates to specialized validators for different markdown elements
    def validate_markdown_syntax
      validate_link_format
      validate_list_format
      validate_headers
    end

    # Checks markdown links for empty text/URLs and valid URL formats
    #
    # Validates URLs follow expected patterns for relative/absolute paths
    def validate_link_format
      content.scan(/\[([^\]]*)\]\(([^)]*)\)/) do |text, url|
        errors << 'Empty link text found' if text.empty?

        errors << 'Empty link URL found' if url.empty?

        # Allow relative paths, absolute paths, HTTP(S) URLs, and common file extensions
        url_pattern = %r{
          ^(?:
            https?://|
            /|
            \.\.?/|
            [a-zA-Z0-9_.-]+(?:/|\.md|\.txt|\.rb|\.html)?|
            [A-Z]+[a-zA-Z]*|
            docs/|
            examples/|
            lib/
          ).*$
        }x
        errors << "Invalid URL format: #{url}" unless url =~ url_pattern
      end
    end

    # Validates list items match expected markdown link format
    #
    # Ensures list items with links have proper syntax with optional descriptions
    def validate_list_format
      content.lines.each_with_index do |line, index|
        next unless line =~ /^[-*]\s+\[/

        # Allow both with and without descriptions
        next if line =~ /^[-*]\s+\[.+\]\(.+\)(?::\s*.+)?$/

        errors << "Invalid list item format at line #{index + 1}"
      end
    end

    # Validates header levels and content
    #
    # Checks for empty H1 headers and warns about headers deeper than H2
    def validate_headers
      content.scan(/^(#+)\s+(.+)$/) do |hashes, text|
        level = hashes.length

        if level == 1 && text.strip.empty?
          errors << 'Empty H1 header text'
        elsif level > 2
          errors << "Headers deeper than H2 not recommended (found H#{level})"
        end
      end
    end

    # Validates link security and format requirements
    #
    # Warns about non-HTTPS URLs and URLs containing spaces
    def validate_links
      urls = content.scan(/\[([^\]]+)\]\(([^)]+)\)/).map(&:last)

      urls.each do |url|
        if url.start_with?('http') && !url.start_with?('https')
          errors << "Non-HTTPS URL found: #{url} (consider using HTTPS)"
        end

        errors << "URL contains spaces: #{url}" if url.include?(' ')
      end
    end

    # Checks file size and individual line lengths against limits
    #
    # Enforces 50KB file size limit and 120 character line length limit
    def validate_file_size
      errors << "File size exceeds maximum (#{MAX_FILE_SIZE} bytes)" if content.bytesize > MAX_FILE_SIZE

      lines = content.lines
      lines.each_with_index do |line, index|
        if line.chomp.length > MAX_LINE_LENGTH
          errors << "Line #{index + 1} exceeds maximum length (#{MAX_LINE_LENGTH} characters)"
        end
      end
    end
  end
end
