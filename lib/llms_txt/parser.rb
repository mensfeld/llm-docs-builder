# frozen_string_literal: true

module LlmsTxt
  class Parser
    attr_reader :file_path, :content

    def initialize(file_path)
      @file_path = file_path
      @content = File.read(file_path)
    end

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

    def save_section(sections, section_name, content)
      return if content.empty?

      sections[section_name] ||= []
      sections[section_name] = parse_section_content(content.join)
    end

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

  class ParsedContent
    attr_reader :sections

    def initialize(sections)
      @sections = sections
    end

    def title
      sections[:title]
    end

    def description
      sections[:description]
    end

    def documentation_links
      sections[:documentation] || []
    end

    def example_links
      sections[:examples] || []
    end

    def optional_links
      sections[:optional] || []
    end

    def to_h
      sections
    end

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
