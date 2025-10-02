# frozen_string_literal: true

module LlmsTxt
  class Validator
    attr_reader :content, :errors

    REQUIRED_SECTIONS = ['# '].freeze
    OPTIONAL_SECTIONS = ['> ', '## Documentation', '## Examples', '## Optional'].freeze
    MAX_LINE_LENGTH = 120
    MAX_FILE_SIZE = 50_000

    def initialize(content)
      @content = content
      @errors = []
    end

    def valid?
      validate!
      errors.empty?
    end

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

    def validate_required_sections
      lines = content.lines

      unless lines.first&.start_with?('# ')
        errors << 'Missing required H1 title (must start with "# ")'
      end

      return unless lines.first&.strip&.length.to_i > 80

      errors << 'Title is too long (max 80 characters)'
    end

    def validate_structure
      lines = content.lines
      h1_count = lines.count { |line| line.start_with?('# ') }

      errors << 'Multiple H1 headers found (only one allowed)' if h1_count > 1

      if lines[1]&.start_with?('> ') && lines[1].strip.length > 200
        errors << 'Description blockquote is too long (max 200 characters)'
      end

      validate_section_order
    end

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

    def validate_markdown_syntax
      validate_link_format
      validate_list_format
      validate_headers
    end

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
        unless url =~ url_pattern
          errors << "Invalid URL format: #{url}"
        end
      end
    end

    def validate_list_format
      content.lines.each_with_index do |line, index|
        next unless line =~ /^[-*]\s+\[/

        # Allow both with and without descriptions
        next if line =~ /^[-*]\s+\[.+\]\(.+\)(?::\s*.+)?$/

        errors << "Invalid list item format at line #{index + 1}"
      end
    end

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

    def validate_links
      links = content.scan(/\[([^\]]+)\]\(([^)]+)\)/)

      links.each do |_text, url|
        if url.start_with?('http') && !url.start_with?('https')
          errors << "Non-HTTPS URL found: #{url} (consider using HTTPS)"
        end

        errors << "URL contains spaces: #{url}" if url.include?(' ')
      end
    end

    def validate_file_size
      if content.bytesize > MAX_FILE_SIZE
        errors << "File size exceeds maximum (#{MAX_FILE_SIZE} bytes)"
      end

      lines = content.lines
      lines.each_with_index do |line, index|
        if line.chomp.length > MAX_LINE_LENGTH
          errors << "Line #{index + 1} exceeds maximum length (#{MAX_LINE_LENGTH} characters)"
        end
      end
    end
  end
end
