# frozen_string_literal: true

require 'cgi'
require 'nokogiri'

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
    Node = Struct.new(:tag, :attrs, :buffer, :skip, :metadata, keyword_init: true)

    HEADING_LEVEL = {
      'h1' => 1,
      'h2' => 2,
      'h3' => 3,
      'h4' => 4,
      'h5' => 5,
      'h6' => 6
    }.freeze

    BLOCK_CONTAINER_TAGS = %w[div aside figure].freeze
    PARAGRAPH_TAGS = %w[p figcaption].freeze
    BLOCK_TAGS = (BLOCK_CONTAINER_TAGS + PARAGRAPH_TAGS).freeze
    LIST_TAGS = %w[ul ol].freeze
    INLINE_STRONG_TAGS = %w[strong b].freeze
    INLINE_EM_TAGS = %w[em i].freeze
    IGNORED_TAGS = %w[script style head noscript iframe svg canvas].freeze
    SELF_CLOSING_TAGS = %w[br hr img].freeze
    VERBATIM_TAGS = %w[code pre].freeze
    TABLE_TAGS = %w[table thead tbody tfoot tr th td caption colgroup col].freeze
    TABLE_CELL_TAGS = %w[th td].freeze
    SELF_CLOSING_TABLE_TAGS = %w[col].freeze
    BLOCK_BOUNDARY_TAGS = (BLOCK_TAGS + %w[blockquote pre ul ol dl hr table] + HEADING_LEVEL.keys).freeze
    MARKDOWN_LABEL_ESCAPE_PATTERN = /[\\\[\]()*_`!]/

    def convert(html)
      return '' if html.nil? || html.strip.empty?

      fragment = Nokogiri::HTML::DocumentFragment.parse(html)
      output = +''
      stack = []
      list_stack = []

      traverse_dom_nodes(fragment.children, stack, list_stack, output)

      # Flush any remaining nodes in case of malformed markup
      until stack.empty?
        node = stack.pop
        rendered = render_node(node, list_stack, stack.last&.tag)
        append_to_parent(stack, output, rendered, node.tag, metadata: node.metadata)
      end

      clean_output(output)
    end

    private

    def traverse_dom_nodes(nodes, stack, list_stack, output)
      nodes.each do |node|
        case node.type
        when Nokogiri::XML::Node::ELEMENT_NODE
          process_element_node(node, stack, list_stack, output)
        when Nokogiri::XML::Node::TEXT_NODE, Nokogiri::XML::Node::CDATA_SECTION_NODE
          append_text(node.text, stack, output)
        when Nokogiri::XML::Node::ENTITY_REF_NODE
          append_text(node.to_s, stack, output)
        when Nokogiri::XML::Node::DOCUMENT_NODE, Nokogiri::XML::Node::DOCUMENT_FRAG_NODE
          traverse_dom_nodes(node.children, stack, list_stack, output)
        else
          # ignore comments, processing instructions, etc.
        end
      end
    end

    def process_element_node(element, stack, list_stack, output)
      tag_name = element.name.downcase
      attrs = extract_attributes(element)

      return if IGNORED_TAGS.include?(tag_name)

      current_table_context = table_context?(stack, tag_name)

      if self_closing_element?(element, tag_name)
        rendered =
          if current_table_context
            build_html_element(tag_name, attrs, self_closing: true)
          else
            render_self_closing(tag_name, attrs, list_stack)
          end
        append_to_parent(stack, output, rendered, tag_name)
        return
      end

      list_stack << { type: :unordered, index: nil } if tag_name == 'ul'
      list_stack << { type: :ordered, index: ordered_list_start_index(attrs) } if tag_name == 'ol'

      node = Node.new(
        tag: tag_name, attrs: attrs, buffer: +'',
        skip: false, metadata: default_metadata(table_context: current_table_context)
      )

      stack << node
      traverse_dom_nodes(element.children, stack, list_stack, output)
      stack.pop

      parent_tag = stack.last&.tag
      rendered = render_node(node, list_stack, parent_tag)
      list_stack.pop if LIST_TAGS.include?(tag_name)

      append_to_parent(stack, output, rendered, tag_name, metadata: node.metadata)
    end

    def extract_attributes(element)
      element.attribute_nodes.each_with_object({}) do |attr, attrs|
        attrs[attr.name.downcase] = attr.value.to_s
      end
    end

    def self_closing_element?(element, tag_name)
      (SELF_CLOSING_TAGS.include?(tag_name) || SELF_CLOSING_TABLE_TAGS.include?(tag_name)) &&
        element.children.empty?
    end

    def append_text(text, stack, output)
      return if text.nil? || text.empty?

      decoded = CGI.unescapeHTML(text)
      return if decoded.empty?

      target = stack.last ? stack.last.buffer : output
      current_node = stack.last

      if inside_verbatim?(stack)
        target << decoded
        return
      end

      whitespace_only = decoded.strip.empty?
      return if whitespace_only && ignorable_whitespace?(decoded, target, current_node)

      normalized = preserve_angle_brackets(decoded)
      normalized = normalize_soft_whitespace(normalized, target) if whitespace_only
      target << normalized
      append_text_fragment(current_node&.metadata&.[](:fragments), normalized)
    end

    def inside_verbatim?(stack)
      stack.any? { |node| VERBATIM_TAGS.include?(node.tag) }
    end

    def preserve_angle_brackets(text)
      return text unless text.include?('<') || text.include?('>')

      text.gsub('<', '&lt;').gsub('>', '&gt;')
    end

    def ignorable_whitespace?(decoded, target, current_node)
      return false unless decoded.strip.empty?
      return true if decoded.include?("\n") && boundary_whitespace?(target, current_node)

      boundary_whitespace?(target, current_node)
    end

    def boundary_whitespace?(target, current_node)
      return true if target.nil? || target.empty?

      last_char = target[-1]
      return true if last_char == "\n"

      return false unless current_node&.tag

      BLOCK_BOUNDARY_TAGS.include?(current_node.tag) && target.rstrip.empty?
    end

    def ordered_list_start_index(attrs)
      value = parse_list_counter(attrs['start'])
      value.nil? ? 1 : value
    end

    def append_to_parent(stack, output, rendered, tag_name = nil, metadata: nil)
      return if rendered.nil? || rendered.empty?

      if stack.last
        parent = stack.last
        buffer = parent.buffer
        break_index = buffer.length if tag_name == 'br'
        buffer << "\n" if needs_block_separator?(buffer, rendered, tag_name)
        base_length = buffer.length
        buffer << rendered
        parent.metadata[:line_break_indices] << break_index if tag_name == 'br' && break_index
        propagate_inline_line_breaks(parent, metadata, base_length)
        append_fragments_to_parent(parent, metadata, rendered, tag_name)
      else
        output << rendered
      end
    end

    def render_self_closing(tag_name, attrs, _list_stack)
      case tag_name
      when 'br'
        "\n"
      when 'hr'
        "\n\n---\n\n"
      when 'img'
        src = attrs['src']
        return '' unless src && !src.empty?

        alt = attrs['alt'] || ''
        escaped_alt = escape_markdown_label(alt)
        title = attrs['title']
        title_part = title && !title.empty? ? %( "#{title}") : ''
        "![#{escaped_alt}](#{src}#{title_part})"
      else
        ''
      end
    end

    def render_node(node, list_stack, parent_tag = nil)
      return '' if node.skip

      tag_name = node.tag
      content = node.buffer
      table_context = node.metadata[:table_context]

      if table_context && !TABLE_TAGS.include?(tag_name)
        rendered = render_html_node(node)
        node.metadata[:rendered_fragments] = markup_fragments(rendered)
        return rendered
      end

      rendered, fragments =
        case tag_name
        when 'body', 'html', 'article', 'section', 'main', 'header', 'footer', 'nav'
          [content, duplicate_fragments(node.metadata[:fragments])]
        when *BLOCK_CONTAINER_TAGS
          rendered_block = block_container(node)
          [rendered_block, markup_fragments(rendered_block)]
        when *PARAGRAPH_TAGS
          rendered_paragraph = paragraph(node)
          [rendered_paragraph, markup_fragments(rendered_paragraph)]
        when 'blockquote'
          rendered_blockquote = blockquote(content)
          [rendered_blockquote, markup_fragments(rendered_blockquote)]
        when 'pre'
          rendered_pre = fenced_code(content)
          [rendered_pre, markup_fragments(rendered_pre)]
        when 'code'
          if parent_tag == 'pre'
            [content, markup_fragments(content)]
          else
            inline = inline_code(content)
            [inline, markup_fragments(inline)]
          end
        when 'span'
          [content, duplicate_fragments(node.metadata[:fragments])]
        when 'a'
          link(node)
        when *INLINE_STRONG_TAGS
          emphasized = emphasis(node, '**')
          [emphasized, markup_fragments(emphasized)]
        when *INLINE_EM_TAGS
          emphasized = emphasis(node, '*')
          [emphasized, markup_fragments(emphasized)]
        when 'u'
          [content, duplicate_fragments(node.metadata[:fragments])]
        when 'br'
          ["\n", markup_fragments("\n")]
        when 'hr'
          ["\n\n---\n\n", markup_fragments("\n\n---\n\n")]
        when 'li'
          rendered_li = list_item(content, list_stack, node.attrs)
          [rendered_li, markup_fragments(rendered_li)]
        when 'ul', 'ol'
          rendered_list = "#{content.rstrip}\n\n"
          [rendered_list, markup_fragments(rendered_list)]
        when 'dl'
          rendered_dl = "#{content}\n"
          [rendered_dl, markup_fragments(rendered_dl)]
        when 'dt'
          stripped = content.strip
          rendered_dt = stripped.empty? ? '' : "#{stripped}\n"
          [rendered_dt, markup_fragments(rendered_dt)]
        when 'dd'
          rendered_dd = ": #{content.strip}\n"
          [rendered_dd, markup_fragments(rendered_dd)]
        when *HEADING_LEVEL.keys
          rendered_heading = heading(tag_name, content)
          [rendered_heading, markup_fragments(rendered_heading)]
        when *TABLE_TAGS
          rendered_table = render_table_node(tag_name, node)
          [rendered_table, markup_fragments(rendered_table)]
        else
          [content, duplicate_fragments(node.metadata[:fragments])]
        end

      fragments = [] if rendered.nil? || rendered.empty?
      node.metadata[:rendered_fragments] = fragments || []
      rendered
    end

    def block_container(node)
      content = node.buffer.to_s
      stripped = content.rstrip
      return '' if stripped.empty?

      "#{stripped}\n\n"
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

    def emphasis(node, marker)
      content = node.buffer.to_s
      line_break_indices = node.metadata[:line_break_indices]

      text =
        if line_break_indices&.any?
          collapse_paragraph_text(content, line_break_indices)
        else
          collapse_whitespace(content)
        end
      return '' if text.empty?

      preserved = []
      text.each_char.with_index do |char, index|
        preserved << (marker.length + index) if char == "\n"
      end
      node.metadata[:preserve_line_break_indices] = preserved

      "#{marker}#{text}#{marker}"
    end

    def inline_code(content)
      text = content.gsub(/\n+/, ' ').strip
      return '' if text.empty?

      max_backticks = text.scan(/`+/).map(&:length).max || 0
      fence = '`' * (max_backticks + 1)
      needs_padding = text.start_with?('`') || text.end_with?('`')
      padding = needs_padding ? ' ' : ''

      "#{fence}#{padding}#{text}#{padding}#{fence}"
    end

    def blockquote(content)
      text = collapse_blockquote_content(content)
      return '' if text.empty?

      inside_code_fence = false
      lines = text.split("\n")
      formatted = lines.map do |line|
        is_code_fence = line.lstrip.start_with?('```')
        if is_code_fence
          inside_code_fence = !inside_code_fence
          fence_line = line.lstrip
          "> #{fence_line}"
        elsif inside_code_fence
          "> #{line}"
        else
          stripped = line.strip
          stripped.empty? ? '>' : "> #{stripped}"
        end
      end.join("\n")
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
      indent_size = list_stack.empty? ? 0 : list_stack.size - 1
      indent = '  ' * indent_size
      continuation_indent = "#{indent}  "

      bullet_prefix =
        if list_info && list_info[:type] == :ordered
          override = parse_list_counter(attrs['value'])
          list_info[:index] = override unless override.nil?
          list_info[:index] ||= 1
          index = list_info[:index]
          list_info[:index] = index + 1
          "#{indent}#{index}. "
        else
          "#{indent}- "
        end

      formatted =
        if nested_list_block?(lines.first)
          "#{bullet_prefix.rstrip}\n"
        else
          first_line = lines.shift
          "#{bullet_prefix}#{first_line.strip}\n"
        end

      lines.each_with_index do |line, index|
        if line.empty?
          next_line = lines[(index + 1)..]&.find { |candidate| !candidate.empty? }
          next if next_line.nil? || block_continuation_line?(next_line)

          formatted << "#{continuation_indent}\n"
          next
        end

        formatted << if line.start_with?('  ')
                       "#{line}\n"
                     else
                       "#{continuation_indent}#{line}\n"
                     end
      end

      formatted
    end

    def link(node)
      attrs = node.attrs
      href = attrs['href']

      raw_fragments = node.metadata[:fragments] || []
      normalized_fragments = normalize_link_fragments(raw_fragments)
      label = normalized_fragments.map { |fragment| fragment[:content] }.join

      if label.empty?
        collapsed = collapse_whitespace(node.buffer)
        label = collapsed unless collapsed.empty?
      end

      label ||= ''
      if href.nil? || href.empty?
        fragments =
          if normalized_fragments.empty?
            label.empty? ? [] : [{ type: :text, content: label }]
          else
            duplicate_fragments(normalized_fragments)
          end
        return [label, fragments]
      end

      effective_fragments =
        if normalized_fragments.empty?
          [{ type: :text, content: label.empty? ? href : label }]
        else
          normalized_fragments
        end

      escaped_fragments = effective_fragments.map do |fragment|
        if fragment[:type] == :text
          { type: :text, content: escape_markdown_label(fragment[:content]) }
        else
          fragment.dup
        end
      end

      escaped_label = escaped_fragments.map { |fragment| fragment[:content] }.join
      output = "[#{escaped_label}](#{href})"
      [output, markup_fragments(output)]
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

      if base_indent&.positive?
        lines.map! do |line|
          next line if block_continuation_line?(line)

          line.sub(/\A[ \t]{0,#{base_indent}}/, '')
        end
      end
      lines
    end

    def needs_block_separator?(buffer, _rendered, tag_name)
      return false if buffer.empty?
      return false if buffer.end_with?("\n")

      block_level_tag?(tag_name)
    end

    def propagate_inline_line_breaks(parent, metadata, base_length)
      return unless metadata

      preserved = metadata[:preserve_line_break_indices]
      return unless preserved&.any?

      preserved.each do |index|
        parent.metadata[:line_break_indices] << (base_length + index)
      end
    end

    def append_fragments_to_parent(parent, metadata, rendered, _tag_name)
      return unless parent

      fragments =
        if metadata && metadata[:rendered_fragments]&.any?
          duplicate_fragments(metadata[:rendered_fragments])
        elsif rendered && !rendered.empty?
          markup_fragments(rendered)
        else
          []
        end
      return if fragments.empty?

      parent_fragments = parent.metadata[:fragments]
      fragments.each do |fragment|
        if fragment[:type] == :text
          append_text_fragment(parent_fragments, fragment[:content])
        else
          parent_fragments << { type: fragment[:type], content: fragment[:content].dup }
        end
      end
    end

    def duplicate_fragments(fragments)
      return [] unless fragments&.any?

      fragments.map do |fragment|
        { type: fragment[:type], content: fragment[:content].dup }
      end
    end

    def markup_fragments(text)
      return [] if text.nil? || text.empty?

      [{ type: :markup, content: text.dup }]
    end

    def append_text_fragment(fragments, text)
      return if fragments.nil?
      return if text.nil? || text.empty?

      fragment_text = text.dup
      if fragments.any? && fragments.last[:type] == :text
        fragments.last[:content] << fragment_text
      else
        fragments << { type: :text, content: fragment_text }
      end
    end

    def normalize_link_fragments(fragments)
      return [] unless fragments&.any?

      normalized = []
      pending_space = false
      output_started = false

      fragments.each do |fragment|
        type = fragment[:type]
        content = fragment[:content]
        next if content.nil? || content.empty?

        if type == :markup
          if pending_space && output_started
            append_text_fragment(normalized, ' ')
            pending_space = false
          end
          normalized << { type: :markup, content: content.dup }
          output_started = true
          next
        end

        squashed = content.gsub(/[ \t\r\n\f\v]+/, ' ')
        squashed.each_char do |char|
          if char == ' '
            pending_space = true if output_started
          else
            if pending_space && output_started
              append_text_fragment(normalized, ' ')
              pending_space = false
            end
            append_text_fragment(normalized, char)
            output_started = true
          end
        end
      end

      normalized
    end

    def block_level_tag?(tag_name)
      tag_name && BLOCK_BOUNDARY_TAGS.include?(tag_name)
    end

    def table_context?(stack, tag_name = nil)
      return true if tag_name && TABLE_TAGS.include?(tag_name)

      stack.any? { |node| node.metadata[:table_context] }
    end

    def normalize_soft_whitespace(text, target)
      return text unless text.include?("\n")

      last_char = target&.[](-1)
      return '' if last_char&.match?(/\s/)

      ' '
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

    def collapse_blockquote_content(content)
      text = content.to_s
      return '' if text.empty?

      segments = text.split(/(```.*?```)/m)
      collapsed = segments.map.with_index do |segment, index|
        if index.odd?
          segment
        else
          collapse_whitespace(segment, preserve_newlines: true)
        end
      end.join
      collapsed.strip
    end

    def collapse_paragraph_text(content, line_break_indices)
      placeholder = '__LLM_DOCS_BR__'
      break_lookup = {}
      line_break_indices.each { |index| break_lookup[index] = true }

      normalized = +''
      content.each_char.with_index do |char, index|
        normalized << if char == "\n"
                        if break_lookup[index]
                          placeholder
                        else
                          ' '
                        end
                      else
                        char
                      end
      end

      collapsed = collapse_whitespace(normalized)
      collapsed.gsub(placeholder, "\n")
    end

    def render_html_node(node)
      tag_name = node.tag
      attrs = node.attrs
      content = node.buffer.to_s

      if SELF_CLOSING_TAGS.include?(tag_name)
        build_html_element(tag_name, attrs, self_closing: true)
      else
        build_html_element(tag_name, attrs, content: content)
      end
    end

    def default_metadata(table_context: false)
      {
        line_break_indices: [],
        table_context: table_context,
        fragments: [],
        rendered_fragments: nil
      }
    end

    def escape_markdown_label(text)
      text.to_s.gsub(MARKDOWN_LABEL_ESCAPE_PATTERN) { |char| "\\#{char}" }
    end

    def clean_output(output)
      cleaned = output.gsub(/\r\n?/, "\n")
      cleaned = cleaned.gsub(/[ \t]+\n/, "\n")
      cleaned = collapse_newlines_outside_code_fences(cleaned)
      cleaned.strip
    end

    def collapse_newlines_outside_code_fences(text)
      segments = text.split(/(```.*?```)/m)
      segments.map.with_index do |segment, index|
        index.odd? ? segment : segment.gsub(/\n{3,}/, "\n\n")
      end.join
    end

    def render_table_node(tag_name, node)
      attrs = node.attrs
      if SELF_CLOSING_TABLE_TAGS.include?(tag_name)
        build_html_element(tag_name, attrs, self_closing: true)
      else
        content = node.buffer.to_s
        content = content.rstrip if TABLE_CELL_TAGS.include?(tag_name)
        html = build_html_element(tag_name, attrs, content: content)
        tag_name == 'table' ? "#{html}\n\n" : html
      end
    end

    def build_html_element(tag_name, attrs, content: '', self_closing: false)
      attributes = serialize_attributes(attrs)
      if self_closing
        "<#{tag_name}#{attributes} />"
      else
        "<#{tag_name}#{attributes}>#{content}</#{tag_name}>"
      end
    end

    def serialize_attributes(attrs)
      return '' unless attrs&.any?

      serialized = attrs.map do |name, value|
        next name if value.nil? || value.empty?

        %(#{name}="#{CGI.escapeHTML(value)}")
      end.join(' ')
      serialized.empty? ? '' : " #{serialized}"
    end
  end
end
