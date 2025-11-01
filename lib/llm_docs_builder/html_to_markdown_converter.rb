# frozen_string_literal: true

require 'cgi'
require 'strscan'

module LlmDocsBuilder
  # Converts HTML fragments into basic markdown.
  #
  # The converter is intentionally lightweight so we can transform remote HTML
  # content fetched by the CLI into markdown before running the rest of the
  # transformation pipeline. We only support the subset of tags commonly found
  # in documentation pages (headings, paragraphs, emphasis, links, lists, code,
  # images, blockquotes, etc.). Unrecognised tags are treated as transparent
  # containers.
  class HtmlToMarkdownConverter
    Token = Struct.new(:type, :value, keyword_init: true)
    Node = Struct.new(:tag, :attrs, :buffer, :skip, :metadata, keyword_init: true)

    HEADING_LEVEL = {
      'h1' => 1,
      'h2' => 2,
      'h3' => 3,
      'h4' => 4,
      'h5' => 5,
      'h6' => 6
    }.freeze

    BLOCK_TAGS = %w[p div aside figure figcaption].freeze
    LIST_TAGS = %w[ul ol].freeze
    INLINE_STRONG_TAGS = %w[strong b].freeze
    INLINE_EM_TAGS = %w[em i].freeze
    IGNORED_TAGS = %w[script style head noscript iframe svg canvas].freeze
    SELF_CLOSING_TAGS = %w[br hr img].freeze
    BLOCK_BOUNDARY_TAGS = (BLOCK_TAGS + %w[blockquote pre ul ol dl hr] + HEADING_LEVEL.keys).freeze

    def convert(html)
      return '' if html.nil? || html.strip.empty?

      output = +''
      stack = []
      list_stack = []

      tokenize(html).each do |token|
        case token.type
        when :text
          append_text(token.value, stack, output)
        when :start_tag
          process_start_tag(token.value, stack, list_stack, output)
        when :end_tag
          process_end_tag(token.value, stack, list_stack, output)
        else
          # do nothing for comments/doctype
        end
      end

      # Flush any remaining nodes in case of malformed markup
      until stack.empty?
        node = stack.pop
        rendered = render_node(node, list_stack, stack.last&.tag)
        append_to_parent(stack, output, rendered, node.tag)
      end

      clean_output(output)
    end

    private

    def tokenize(html)
      scanner = StringScanner.new(html)
      tokens = []

      until scanner.eos?
        if scanner.scan(/<!--.*?-->/m)
          tokens << Token.new(type: :comment, value: scanner.matched)
        elsif scanner.scan(/<!DOCTYPE.*?>/mi)
          tokens << Token.new(type: :doctype, value: scanner.matched)
        elsif scanner.scan(/<\/?[A-Za-z0-9:-]+\b[^>]*>/m)
          raw = scanner.matched
          if raw.start_with?('</')
            tokens << Token.new(type: :end_tag, value: raw)
          else
            tokens << Token.new(type: :start_tag, value: raw)
          end
        else
          text = scanner.scan(/[^<]+/m)
          tokens << Token.new(type: :text, value: text) if text
        end
      end

      tokens
    end

    def append_text(text, stack, output)
      return if text.nil? || text.empty?

      decoded = CGI.unescapeHTML(text)
      return if decoded.empty?
      return if decoded.strip.empty? && decoded.include?("\n")

      target = stack.last ? stack.last.buffer : output
      target << decoded
    end

    def process_start_tag(raw, stack, list_stack, output)
      tag_name, attrs, self_closing = parse_start_tag(raw)
      return unless tag_name

      if IGNORED_TAGS.include?(tag_name)
        stack << Node.new(tag: tag_name, attrs: attrs, buffer: +'',
                          skip: true, metadata: default_metadata)
        return
      end

      if self_closing
        rendered = render_self_closing(tag_name, attrs, list_stack)
        append_to_parent(stack, output, rendered, tag_name)
        return
      end

      list_stack << { type: :unordered, index: nil } if tag_name == 'ul'
      list_stack << { type: :ordered, index: ordered_list_start_index(attrs) } if tag_name == 'ol'

      stack << Node.new(tag: tag_name, attrs: attrs, buffer: +'', skip: false,
                        metadata: default_metadata)
    end

    def ordered_list_start_index(attrs)
      parse_list_counter(attrs['start']) || 1
    end

    def process_end_tag(raw, stack, list_stack, output)
      tag_name = raw[/<\/\s*([A-Za-z0-9:-]+)/, 1]&.downcase
      return unless tag_name

      node = nil

      while (current = stack.pop)
        node = current
        break if node.tag == tag_name
      end

      return unless node

      parent_tag = stack.last&.tag
      rendered = render_node(node, list_stack, parent_tag)
      list_stack.pop if LIST_TAGS.include?(tag_name)

      append_to_parent(stack, output, rendered, node.tag)
    end

    def append_to_parent(stack, output, rendered, tag_name = nil)
      return if rendered.nil? || rendered.empty?

      if stack.last
        parent = stack.last
        buffer = parent.buffer
        break_index = buffer.length if tag_name == 'br'
        buffer << "\n" if needs_block_separator?(buffer, rendered, tag_name)
        buffer << rendered
        if tag_name == 'br' && break_index
          parent.metadata[:line_break_indices] << break_index
        end
      else
        output << rendered
      end
    end

    def parse_start_tag(raw)
      scanner = StringScanner.new(raw)
      scanner.scan(/<\s*/)
      tag_name = scanner.scan(/[A-Za-z0-9:-]+/)
      return unless tag_name

      tag_name = tag_name.downcase
      attrs = {}

      until scanner.match?(/\s*\/?\s*>/)
        name = scanner.scan(/\s*[A-Za-z0-9:-]+/)
        break unless name

        name = name.strip.downcase
        value = nil

        if scanner.scan(/\s*=\s*/)
          quote = scanner.getch
          if quote == '"' || quote == "'"
            value = scanner.scan_until(/#{quote}/)
            value&.chop!
          else
            scanner.ungetc(quote)
            value = scanner.scan(/[^\s>]+/)
          end
        end

        attrs[name] = CGI.unescapeHTML(value || '')
      end

      self_closing = scanner.match?(/\s*\/\s*>/)
      [tag_name, attrs, self_closing || SELF_CLOSING_TAGS.include?(tag_name)]
    end

    def render_self_closing(tag_name, attrs, list_stack)
      case tag_name
      when 'br'
        "\n"
      when 'hr'
        "\n\n---\n\n"
      when 'img'
        src = attrs['src']
        return '' unless src && !src.empty?

        alt = attrs['alt'] || ''
        title = attrs['title']
        title_part = title && !title.empty? ? %( "#{title}") : ''
        "![#{alt}](#{src}#{title_part})"
      else
        ''
      end
    end

    def render_node(node, list_stack, parent_tag = nil)
      return '' if node.skip

      tag_name = node.tag
      content = node.buffer

      case tag_name
      when 'body', 'html', 'article', 'section', 'main', 'header', 'footer', 'nav'
        content
      when *BLOCK_TAGS
        paragraph(node)
      when 'blockquote'
        blockquote(content)
      when 'pre'
        fenced_code(content)
      when 'code'
        parent_tag == 'pre' ? content : inline_code(content)
      when 'span'
        content
      when 'a'
        link(content, node.attrs)
      when *INLINE_STRONG_TAGS
        emphasis(content, '**')
      when *INLINE_EM_TAGS
        emphasis(content, '*')
      when 'u'
        content
      when 'br'
        "\n"
      when 'hr'
        "\n\n---\n\n"
      when 'li'
        list_item(content, list_stack, node.attrs)
      when 'ul', 'ol'
        "#{content.rstrip}\n"
      when 'dl'
        "#{content}\n"
      when 'dt'
        content.strip
      when 'dd'
        ": #{content.strip}\n"
      when *HEADING_LEVEL.keys
        heading(tag_name, content)
      else
        content
      end
    end

    def paragraph(node)
      content = node.buffer.to_s
      line_break_indices = node.metadata[:line_break_indices]

      text =
        if line_break_indices&.any?
          collapse_paragraph_text(content, line_break_indices)
        else
          collapse_whitespace(content)
        end
      return '' if text.empty?

      "#{text}\n\n"
    end

    def heading(tag_name, content)
      level = HEADING_LEVEL[tag_name] || 1
      text = collapse_whitespace(content)
      return '' if text.empty?

      "#{'#' * level} #{text}\n\n"
    end

    def emphasis(content, marker)
      text = collapse_whitespace(content)
      return '' if text.empty?

      "#{marker}#{text}#{marker}"
    end

    def inline_code(content)
      text = content.gsub(/\n+/, ' ').strip
      return '' if text.empty?

      "`#{text}`"
    end

    def blockquote(content)
      lines = collapse_whitespace(content).split(/\n+/)
      formatted = lines.map { |line| "> #{line.strip}" }.join("\n")
      "#{formatted}\n\n"
    end

    def fenced_code(content)
      text = content.delete_prefix("\n").rstrip
      return '' if text.empty?

      "```\n#{text}\n```\n\n"
    end

    def list_item(content, list_stack, attrs = {})
      lines = normalize_list_item_lines(content)
      return '' if lines.empty?

      list_info = list_stack.last
      indent = '  ' * (list_stack.size - 1)
      continuation_indent = "#{indent}  "

      bullet_prefix =
        if list_info && list_info[:type] == :ordered
          list_info[:index] = parse_list_counter(attrs['value']) || list_info[:index]
          index = list_info[:index]
          list_info[:index] += 1
          "#{indent}#{index}. "
        else
          "#{indent}- "
        end

      formatted =
        if nested_list_block?(lines.first)
          +"#{bullet_prefix.rstrip}\n"
        else
          first_line = lines.shift
          +"#{bullet_prefix}#{first_line.strip}\n"
        end

      lines.each_with_index do |line, index|
        if line.empty?
          next_line = lines[index + 1..]&.find { |candidate| !candidate.empty? }
          next if next_line.nil? || block_continuation_line?(next_line)

          formatted << "#{continuation_indent}\n"
          next
        end

        if line.start_with?('  ')
          formatted << "#{line}\n"
        else
          formatted << "#{continuation_indent}#{line}\n"
        end
      end

      formatted
    end

    def link(content, attrs)
      href = attrs['href']
      text = collapse_whitespace(content)
      text = href if text.empty?

      return text unless href && !href.empty?

      "[#{text}](#{href})"
    end

    def normalize_list_item_lines(content)
      text = content.to_s.gsub(/\r\n?/, "\n")
      text = text.gsub(/(?<!\s)([ \t]{2,}(?:[-+*]|\d+\.)\s)/, "\n\\1")
      text = text.gsub(/(?<!\s)([ \t]{2,}>)/, "\n\\1")

      lines = text.lines.map(&:rstrip)
      lines.shift while lines.first&.empty?
      lines.pop while lines.last&.empty?
      non_empty = lines.reject(&:empty?)
      base_candidates = non_empty.reject { |line| block_continuation_line?(line) }
      base_indent = base_candidates.map { |line| line[/\A[ \t]*/].size }.min

      if base_indent && base_indent.positive?
        lines.map! do |line|
          next line if block_continuation_line?(line)

          line.sub(/\A[ \t]{0,#{base_indent}}/, '')
        end
      end
      lines
    end

    def needs_block_separator?(buffer, rendered, tag_name)
      return false if buffer.empty?
      return false if buffer.end_with?("\n")

      block_level_tag?(tag_name)
    end

    def block_level_tag?(tag_name)
      tag_name && BLOCK_BOUNDARY_TAGS.include?(tag_name)
    end

    def block_continuation_line?(line)
      stripped = line.lstrip
      return false if stripped.empty?

      stripped.start_with?('- ', '* ', '+ ') ||
        stripped.match?(/\A\d+\.\s/) ||
        stripped.start_with?('> ') ||
        stripped.start_with?('```')
    end

    def nested_list_block?(line)
      return false unless line

      line.start_with?('  ') && line.lstrip.match?(/\A([-+*]|\d+\.)\s/)
    end

    def parse_list_counter(raw)
      return nil if raw.nil?

      normalized = raw.strip
      return nil if normalized.empty?
      return nil unless normalized.match?(/\A[+-]?\d+\z/)

      normalized.to_i
    end

    def collapse_whitespace(content, preserve_newlines: false)
      text = content.to_s
      return '' if text.empty?

      if preserve_newlines
        normalized = text.gsub(/[ \t\r\f\v]+/, ' ')
        normalized = normalized.gsub(/[ \t\f\v]*\n/, "\n")
        normalized = normalized.gsub(/\n[ \t\f\v]*/, "\n")
        normalized.strip
      else
        text.gsub(/[ \t\r\n\f\v]+/, ' ').strip
      end
    end

    def collapse_paragraph_text(content, line_break_indices)
      placeholder = '__LLM_DOCS_BR__'
      break_lookup = {}
      line_break_indices.each { |index| break_lookup[index] = true }

      normalized = +''
      content.each_char.with_index do |char, index|
        if char == "\n"
          if break_lookup[index]
            normalized << placeholder
          else
            normalized << ' '
          end
        else
          normalized << char
        end
      end

      collapsed = collapse_whitespace(normalized)
      collapsed.gsub(placeholder, "\n")
    end

    def default_metadata
      { line_break_indices: [] }
    end

    def clean_output(output)
      cleaned = output.gsub(/\r\n?/, "\n")
      cleaned = cleaned.gsub(/[ \t]+\n/, "\n")
      cleaned = cleaned.gsub(/\n{3,}/, "\n\n")
      cleaned.strip
    end
  end
end
