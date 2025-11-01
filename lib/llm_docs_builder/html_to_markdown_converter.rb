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
    Node = Struct.new(:tag, :attrs, :buffer, :skip, keyword_init: true)

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
        rendered = render_node(node, list_stack)
        append_to_parent(stack, output, rendered)
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
      target = stack.last ? stack.last.buffer : output
      target << decoded
    end

    def process_start_tag(raw, stack, list_stack, output)
      tag_name, attrs, self_closing = parse_start_tag(raw)
      return unless tag_name

      if IGNORED_TAGS.include?(tag_name)
        stack << Node.new(tag: tag_name, attrs: attrs, buffer: +'',
                          skip: true)
        return
      end

      if self_closing
        rendered = render_self_closing(tag_name, attrs, list_stack)
        append_to_parent(stack, output, rendered)
        return
      end

      list_stack << { type: :unordered, index: nil } if tag_name == 'ul'
      list_stack << { type: :ordered, index: 1 } if tag_name == 'ol'

      stack << Node.new(tag: tag_name, attrs: attrs, buffer: +'', skip: false)
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

      rendered = render_node(node, list_stack)
      list_stack.pop if LIST_TAGS.include?(tag_name)

      append_to_parent(stack, output, rendered)
    end

    def append_to_parent(stack, output, rendered)
      return if rendered.nil? || rendered.empty?

      if stack.last
        stack.last.buffer << rendered
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

    def render_node(node, list_stack)
      return '' if node.skip

      tag_name = node.tag
      content = node.buffer

      case tag_name
      when 'body', 'html', 'article', 'section', 'main', 'header', 'footer', 'nav'
        content
      when *BLOCK_TAGS
        paragraph(content)
      when 'blockquote'
        blockquote(content)
      when 'pre'
        fenced_code(content)
      when 'code'
        inline_code(content)
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
        list_item(content, list_stack)
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

    def paragraph(content)
      text = collapse_whitespace(content)
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

    def list_item(content, list_stack)
      text = collapse_whitespace(content)
      return '' if text.empty?

      list_info = list_stack.last
      indent = '  ' * (list_stack.size - 1)

      if list_info && list_info[:type] == :ordered
        index = list_info[:index]
        list_info[:index] += 1
        "#{indent}#{index}. #{text}\n"
      else
        "#{indent}- #{text}\n"
      end
    end

    def link(content, attrs)
      href = attrs['href']
      text = collapse_whitespace(content)
      text = href if text.empty?

      return text unless href && !href.empty?

      "[#{text}](#{href})"
    end

    def collapse_whitespace(content)
      content.to_s.gsub(/\s+/, ' ').strip
    end

    def clean_output(output)
      cleaned = output.gsub(/\r\n?/, "\n")
      cleaned = cleaned.gsub(/[ \t]+\n/, "\n")
      cleaned = cleaned.gsub(/\n{3,}/, "\n\n")
      cleaned.strip
    end
  end
end
