# frozen_string_literal: true

module LlmDocsBuilder
  # Parses llms.txt files into structured data
  #
  # Reads and parses llms.txt files according to the llms.txt specification,
  # extracting the title, description, and structured sections (Documentation,
  # Examples, Optional) with their links.
  #
  # @example Parse an llms.txt file
  #   parser = LlmDocsBuilder::Parser.new('llms.txt')
  #   parsed = parser.parse
  #   parsed.title              # => "My Project"
  #   parsed.description        # => "Project description"
  #   parsed.documentation_links # => [{title: "README", url: "...", description: "..."}]
  #
  # @api public
  class Parser
    # @return [String] path to the llms.txt file
    attr_reader :file_path

    # @return [String] raw content of the llms.txt file
    attr_reader :content

    # Initialize a new parser
    #
    # @param file_path [String] path to the llms.txt file to parse
    def initialize(file_path)
      @file_path = file_path
      @content = File.read(file_path)
    end

    # Parse the llms.txt file
    #
    # Parses the file content and returns a {ParsedContent} object containing
    # the extracted title, description, and structured sections with links.
    #
    # @return [ParsedContent] parsed content with title, description, and sections
    def parse
      sections = {}
      current_section = nil
      current_content = []

      lines = content.lines

      lines.each_with_index do |line, index|
        if line.start_with?('# ')
          save_section(sections, current_section, current_content) if current_section

          sections[:title] = line[2..].strip if sections.empty?
          current_section = :description if index == 1 && line.start_with?('> ')
          current_content = []
        elsif line.start_with?('> ') && sections[:title] && !sections[:description]
          sections[:description] = line[2..].strip
        elsif line.start_with?('## ')
          save_section(sections, current_section, current_content) if current_section

          current_section = line[3..].strip.downcase.gsub(/\s+/, '_').to_sym
          current_content = []
        elsif !line.strip.empty?
          current_content << line
        end
      end

      save_section(sections, current_section, current_content) if current_section

      ParsedContent.new(sections)
    end

    private

    # Parses and stores section content in the sections hash
    #
    # Skips empty sections and delegates to parse_section_content for processing
    #
    # @param sections [Hash] accumulator hash for sections
    # @param section_name [Symbol] name of the section
    # @param content [Array<String>] raw content lines
    def save_section(sections, section_name, content)
      return if content.empty?

      sections[section_name] ||= []
      sections[section_name] = parse_section_content(content.join)
    end

    # Extracts markdown links from section content into structured format
    #
    # Scans for markdown list items with links and descriptions. Returns raw content
    # if no links are found in the expected format.
    #
    # @param content [String] raw section content
    # @return [Array<Hash>, String] array of link hashes or raw content if no links found
    def parse_section_content(content)
      links = []

      content.scan(/^[-*]\s*\[([^\]]+)\]\(([^)]+)\):\s*(.*)$/m) do |title, url, description|
        links << {
          title: title,
          url: url,
          description: description.strip
        }
      end

      links.empty? ? content.strip : links
    end
  end

  # Represents parsed llms.txt content with structured access to sections
  #
  # Provides convenient access to parsed llms.txt sections including title,
  # description, and link collections. Can be converted to Hash or XML formats.
  #
  # @example Access parsed content
  #   parsed.title              # => "My Project"
  #   parsed.description        # => "A description"
  #   parsed.documentation_links # => [{title: "...", url: "...", description: "..."}]
  #   parsed.to_h               # => Hash representation
  #   parsed.to_xml             # => XML string
  #
  # @api public
  class ParsedContent
    # @return [Hash] the parsed sections hash
    attr_reader :sections

    # Initialize parsed content
    #
    # @param sections [Hash] hash containing parsed sections (:title, :description, :documentation, etc.)
    def initialize(sections)
      @sections = sections
    end

    # Get the project title
    #
    # @return [String, nil] the H1 title or nil if not present
    def title
      sections[:title]
    end

    # Get the project description
    #
    # @return [String, nil] the description blockquote or nil if not present
    def description
      sections[:description]
    end

    # Get documentation links
    #
    # @return [Array<Hash>] array of documentation links with :title, :url, and :description
    def documentation_links
      sections[:documentation] || []
    end

    # Get example links
    #
    # @return [Array<Hash>] array of example links with :title, :url, and :description
    def example_links
      sections[:examples] || []
    end

    # Get optional links
    #
    # @return [Array<Hash>] array of optional links with :title, :url, and :description
    def optional_links
      sections[:optional] || []
    end

    # Convert to hash representation
    #
    # @return [Hash] hash containing all parsed sections
    def to_h
      sections
    end

    # Convert to XML representation
    #
    # Generates an XML document with all parsed sections and links.
    #
    # @return [String] XML string representation
    def to_xml
      builder = []
      builder << '<?xml version="1.0" encoding="UTF-8"?>'
      builder << '<llms_context>'
      builder << "  <title>#{title}</title>" if title
      builder << "  <description>#{description}</description>" if description

      add_xml_section(builder, 'documentation', documentation_links)
      add_xml_section(builder, 'examples', example_links)
      add_xml_section(builder, 'optional', optional_links) if sections[:optional]

      builder << '</llms_context>'
      builder.join("\n")
    end

    private

    # Appends section XML elements to builder array
    #
    # Handles both array of link hashes and raw string content
    #
    # @param builder [Array<String>] XML lines accumulator
    # @param name [String] section name
    # @param links [Array<Hash>, String] section links or content
    def add_xml_section(builder, name, links)
      return if links.empty?

      builder << "  <#{name}>"

      if links.is_a?(Array)
        links.each do |link|
          builder << '    <link>'
          builder << "      <title>#{link[:title]}</title>"
          builder << "      <url>#{link[:url]}</url>"
          builder << "      <description>#{link[:description]}</description>"
          builder << '    </link>'
        end
      else
        builder << "    #{links}"
      end

      builder << "  </#{name}>"
    end
  end
end
