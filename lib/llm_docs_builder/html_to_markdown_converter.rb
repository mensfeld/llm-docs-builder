# frozen_string_literal: true

module LlmDocsBuilder
  # A lightweight HTML → Markdown converter using only Nokogiri's public API.
  #
  # Design goals:
  # - Traverse with Nokogiri and keep logic small, readable, and predictable
  # - Preserve the existing public behavior covered by specs
  # - Convert tables into Markdown while preserving inline formatting
  class HtmlToMarkdownConverter
    HEADING_LEVEL = {
      'h1' => 1,
      'h2' => 2,
      'h3' => 3,
      'h4' => 4,
      'h5' => 5,
      'h6' => 6
    }.freeze

    BLOCK_CONTAINERS = %w[div aside figure article section main header footer nav body html].freeze
    INLINE_STRONG_TAGS = %w[strong b].freeze
    INLINE_EM_TAGS = %w[em i].freeze
    LIST_TAGS = %w[ul ol].freeze
    IGNORE_TAGS = %w[script style head noscript iframe svg canvas].freeze
    MARKDOWN_LABEL_ESCAPE_PATTERN = /[\\\[\]()*_`!]/
    SAFE_URI_SCHEMES = %w[http https mailto ftp tel].freeze

    # Entry point
    def convert(html)
      return '' if html.nil? || html.strip.empty?

      fragment = Nokogiri::HTML::DocumentFragment.parse(html)
      rendered = render_blocks(fragment.children, depth: 0)
      clean_output(rendered)
    end

    # Initialize table renderer
    def table_renderer
      @table_renderer ||= HtmlToMarkdown::TableMarkupRenderer.new(
        inline_collapser: method(:collapsed_inline_for),
        block_renderer: method(:render_blocks)
      )
    end

    private

    # Renders a sequence of block-level nodes, inserting a blank line between blocks
    def render_blocks(nodes, depth: 0)
      parts = []
      inline_buffer = []

      flush_inline = lambda do
        unless inline_buffer.empty?
          rendered_inline = collapse_inline_preserving_newlines(render_inline_nodes(inline_buffer))
          inline_buffer.clear
          parts << rendered_inline unless rendered_inline.empty?
        end
      end

      nodes.each do |node|
        if node.text?
          inline_buffer << node
          next
        end

        next unless node.element?

        tag = node.name.downcase
        next if IGNORE_TAGS.include?(tag)

        if block_like?(node)
          flush_inline.call
          rendered = render_element_block(node, depth: depth)
          parts << rendered unless rendered.nil? || rendered.strip.empty?
        else
          inline_buffer << node
        end
      end

      flush_inline.call

      parts.join("\n\n")
    end

    def render_element_block(element, depth: 0)
      tag = element.name.downcase

      return table_renderer.render_table(element) if tag == 'table'

      case tag
      when 'hr'
        '---'
      when *HEADING_LEVEL.keys
        text = collapsed_inline_for(element)
        return '' if text.empty?

        "#{'#' * HEADING_LEVEL[tag]} #{text}"
      when 'blockquote'
        render_blockquote(element)
      when 'pre'
        render_fenced_code(element)
      when 'img'
        # Allow images to be emitted as their own block when they appear
        # directly under block containers (e.g., inside <figure>).
        render_image(element)
      when 'ul'
        render_list(element, ordered: false, depth: depth)
      when 'ol'
        start_index = parse_integer(element['start']) || 1
        render_list(element, ordered: true, depth: depth, start: start_index)
      when 'dl'
        render_definition_list(element)
      when 'figure'
        render_figure(element, depth: depth)
      when *BLOCK_CONTAINERS
        # Transparent block container: render its children as blocks.
        # If the container only has inline/text content, render that inline instead.
        render_transparent_container(element, depth: depth)
      else
        # Fallback: inline container at block level
        collapsed_inline_for(element)
      end
    end

    # Inline rendering
    # Returns [string, has_markdown]
    def render_inline(node, escape_for_label: false)
      if node.text?
        text = inline_text(node.text)
        return [escape_for_label ? escape_markdown_label(text) : text, false]
      end

      tag = node.name.downcase if node.element?
      case tag
      when 'br'
        ["\n", false]
      when 'img'
        [render_image(node), true]
      when 'a'
        render_link(node)
      when *INLINE_STRONG_TAGS
        render_wrapped_inline(node, '**', escape_for_label: escape_for_label)
      when *INLINE_EM_TAGS
        render_wrapped_inline(node, '*', escape_for_label: escape_for_label)
      when 'code'
        [render_inline_code(node), true]
      else
        render_inline_children(node, escape_for_label: escape_for_label)
      end
    end

    def render_transparent_container(element, depth:)
      blocks = render_blocks(element.children, depth: depth)
      if blocks.strip.empty?
        collapsed_inline_for(element)
      else
        blocks
      end
    end

    def render_figure(element, depth:)
      renderer = HtmlToMarkdown::FigureCodeBlockRenderer.new(
        element,
        inline_collapser: method(:collapsed_inline_for),
        fence_calculator: method(:compute_code_fence)
      )
      rendered = renderer.render
      return render_transparent_container(element, depth: depth) if rendered.nil? || rendered.strip.empty?

      render_figure_children_in_original_order(
        element,
        code_block_node: renderer.code_block_node,
        rendered_code: rendered,
        depth: depth
      )
    end

    def render_figure_children_in_original_order(element, code_block_node:, rendered_code:, depth:)
      direct_code_child = figure_direct_child_for(element, code_block_node)
      parts = []
      code_inserted = false

      element.children.each do |child|
        next if figcaption?(child)
        next if child.text? && child.text.strip.empty?

        if !direct_code_child.nil? && child.equal?(direct_code_child)
          parts << rendered_code
          code_inserted = true
          next
        end

        rendered_child = render_blocks([child], depth: depth)
        parts << rendered_child unless rendered_child.nil? || rendered_child.strip.empty?
      end

      parts.unshift(rendered_code) unless code_inserted
      parts.join("\n\n")
    end

    def figure_direct_child_for(element, node)
      return nil if node.nil?

      current = node
      current = current.parent until current.nil? || current.parent.nil? || current.parent.equal?(element)

      return nil if current.nil? || !current.parent.equal?(element)

      current
    end

    def figcaption?(node)
      node.element? && node.name.casecmp('figcaption').zero?
    end

    def render_inline_children(parent, escape_for_label: false)
      has_markdown = false
      parts = []

      parent.children.each do |child|
        next if child.parent.nil?

        s, marked, metadata = render_inline(child, escape_for_label: escape_for_label)
        Helpers.prune_trailing_unsafe_link_separator!(parts) if metadata == :unsafe_link_pruned
        next if s.nil? || s.empty?

        parts << s
        has_markdown ||= marked
      end

      [parts.join, has_markdown]
    end

    def render_inline_string(parent)
      s, = render_inline_children(parent)
      s
    end

    def collapsed_inline_for(parent)
      collapse_inline_preserving_newlines(render_inline_string(parent))
    end

    def render_wrapped_inline(node, wrapper, escape_for_label: false)
      if escape_for_label
        s, = render_inline_children(node, escape_for_label: true)
        content = collapse_inline_preserving_newlines(s)
      else
        content = collapsed_inline_for(node)
      end
      return ['', false] if content.empty?

      ["#{wrapper}#{content}#{wrapper}", true]
    end

    def render_inline_nodes(nodes)
      return '' if nodes.nil? || nodes.empty?

      parts = []
      nodes.each do |node|
        s, = render_inline(node)
        parts << s unless s.nil? || s.empty?
      end

      parts.join
    end

    def render_link(node)
      href = (node['href'] || '').to_s
      sanitized_href = href.strip

      if sanitized_href.empty?
        label_str, label_has_md = render_inline_children(node)
        label = collapse_inline_preserving_newlines(label_str)
        return [label, label_has_md]
      end

      unless safe_link_destination?(sanitized_href)
        prune_unsafe_link_separators(node)
        return ['', false, :unsafe_link_pruned]
      end

      label_str, = render_inline_children(node, escape_for_label: true)
      label = collapse_inline_preserving_newlines(label_str)
      destination = format_markdown_link_destination(sanitized_href)
      ["[#{label}](#{destination})", true]
    end

    def render_image(node)
      src = (node['src'] || '').to_s
      return '' if src.empty?

      alt = (node['alt'] || '').to_s
      title = (node['title'] || '').to_s
      title_part = title.empty? ? '' : %( "#{title}")
      destination = format_markdown_link_destination(src)
      "![#{escape_markdown_label(alt)}](#{destination}#{title_part})"
    end

    def render_inline_code(node)
      text = node.text.to_s.gsub(/\r\n?/, "\n").gsub(/\n+/, ' ').strip
      return '' if text.empty?

      fence_len = (text.scan(/`+/).map(&:length).max || 0) + 1
      fence = '`' * fence_len
      "#{fence}#{text}#{fence}"
    end

    def render_blockquote(node)
      # Render blockquote differently based on whether it contains block-level elements.
      # If it only has inline/text content, preserve the inline sequence instead of
      # attempting block rendering (which would drop surrounding text nodes).
      has_block_children = node.element_children.any? { |child| block_like?(child) }

      inner =
        if has_block_children
          render_blocks(node.children, depth: 0)
        else
          collapsed_inline_for(node)
        end
      return '' if inner.strip.empty?

      lines = inner.split("\n")
      lines.map { |line| line.strip.empty? ? '>' : "> #{line}" }.join("\n")
    end

    def render_fenced_code(node)
      inner_code = node.at_css('code')
      code = inner_code ? inner_code.text.to_s : node.text.to_s
      code = code.gsub(/\r\n?/, "\n").rstrip
      fence = compute_code_fence(code)
      "#{fence}\n#{code}\n#{fence}"
    end

    def compute_code_fence(code)
      text = code.to_s
      longest_sequence = text.scan(/`+/).map(&:length).max || 0
      fence_length = [3, longest_sequence + 1].max
      '`' * fence_length
    end

    def render_list(list_node, ordered:, depth:, start: nil)
      lines = []
      index = ordered ? (start || 1) : nil
      indent = '  ' * depth

      list_node.element_children.each do |child|
        next unless child.name.downcase == 'li'

        override = ordered ? parse_integer(child['value']) : nil
        index = override unless override.nil?

        prefix =
          if ordered
            "#{indent}#{index}. "
          else
            "#{indent}- "
          end

        index = (index || 0) + 1 if ordered

        segments = build_list_item_segments(child)
        inline_text, segments = extract_leading_inline_text(segments, depth: depth)
        inline_text = collapse_inline_preserving_newlines(inline_text)

        bullet_line = inline_text.empty? ? prefix.rstrip : "#{prefix}#{inline_text}"
        item_lines = [bullet_line]

        previous_type = nil
        segments.each do |segment|
          segment_lines = render_list_item_segment(segment, depth: depth)
          next if segment_lines.empty?

          insert_blank_line =
            case segment.first
            when :nested_list
              %i[block inline].include?(previous_type)
            else
              true
            end

          item_lines << '' if insert_blank_line && !item_lines.last.to_s.empty?
          item_lines.concat(segment_lines)
          previous_type = segment.first
        end

        lines << item_lines.join("\n")
      end

      lines.join("\n")
    end

    def build_list_item_segments(list_item)
      segments = []
      inline_buffer = []

      list_item.children.each do |child|
        if child.element? && LIST_TAGS.include?(child.name.downcase)
          segments << [:inline, inline_buffer] unless inline_buffer.empty?
          inline_buffer = []
          segments << [:nested_list, child]
        elsif block_like?(child)
          segments << [:inline, inline_buffer] unless inline_buffer.empty?
          inline_buffer = []
          segments << [:block, child]
        else
          inline_buffer << child
        end
      end

      segments << [:inline, inline_buffer] unless inline_buffer.empty?
      segments
    end

    def extract_leading_inline_text(segments, depth:)
      loop do
        return ['', segments] if segments.empty?

        type, value = segments.first

        case type
        when :inline
          segments.shift
          candidate = collapse_inline_preserving_newlines(render_inline_nodes(value))
          next if candidate.empty?

          return [candidate, segments]
        when :block
          rendered = render_element_block(value, depth: depth + 1)
          if rendered && !rendered.include?("\n")
            segments.shift
            return [collapse_inline_preserving_newlines(rendered), segments]
          end

          return ['', segments]
        else
          return ['', segments]
        end
      end
    end

    def render_list_item_segment(segment, depth:)
      type, value = segment

      case type
      when :block
        rendered = render_element_block(value, depth: depth + 1)
        return [] if rendered.nil? || rendered.strip.empty?

        indent_list_block_lines(rendered, depth + 1)
      when :inline
        rendered = collapse_inline_preserving_newlines(render_inline_nodes(value))
        return [] if rendered.empty?

        indent_list_block_lines(rendered, depth + 1)
      when :nested_list
        ordered = value.name.downcase == 'ol'
        nested = render_list(
          value,
          ordered: ordered,
          depth: depth + 1,
          start: ordered ? parse_integer(value['start']) : nil
        )
        nested.empty? ? [] : nested.split("\n")
      else
        []
      end
    end

    def indent_list_block_lines(text, depth)
      indent = '  ' * depth

      text.split("\n").map do |line|
        line.strip.empty? ? '' : "#{indent}#{line}"
      end
    end

    def render_definition_list(dl_node)
      out = []
      pending_term = nil
      pending_definitions = []

      flush_pending = lambda do
        return if pending_term.nil? || pending_definitions.empty?

        entry = "#{pending_term}\n: #{pending_definitions.first}"
        pending_definitions.drop(1).each do |definition|
          entry << "\n: #{definition}"
        end

        out << entry
        pending_term = nil
        pending_definitions = []
      end

      dl_node.element_children.each do |child|
        case child.name.downcase
        when 'dt'
          flush_pending.call
          pending_term = collapsed_inline_for(child)
          pending_definitions = []
        when 'dd'
          defn = collapsed_inline_for(child)
          pending_definitions << defn if pending_term
        end
      end

      flush_pending.call

      out.join("\n\n")
    end

    # Helpers
    def normalize_whitespace(text)
      text.gsub(/[ \t\r\n\f\v]+/, ' ')
    end

    def inline_text(text)
      return '' if text.nil? || text.empty?

      decoded = CGI.unescapeHTML(text)
      return '' if decoded.empty?

      safe = decoded.gsub('<', '&lt;').gsub('>', '&gt;')
      normalize_whitespace(safe)
    end

    def collapse_inline_preserving_newlines(text)
      return '' if text.nil? || text.empty?

      placeholder = '__LLM_BR__'
      marked = text.gsub("\r\n", "\n").tr("\r", "\n").gsub("\n", placeholder)
      collapsed = normalize_whitespace(marked).strip
      collapsed.gsub(placeholder, "\n")
    end

    def escape_markdown_label(text)
      text.to_s.gsub(MARKDOWN_LABEL_ESCAPE_PATTERN) { |char| "\\#{char}" }
    end

    def format_markdown_link_destination(url)
      return '' if url.nil?

      str = url.to_s
      return str if str.empty?

      # Wrap in angle brackets when the URL contains characters that often
      # confuse markdown link destination parsing (e.g., spaces or parentheses).
      # CommonMark allows the form: [label](<url>)
      if str.match?(/[\s()]/)
        "<#{str}>"
      else
        str
      end
    end

    def safe_link_destination?(href)
      return false if href.nil?

      sanitized = href.strip
      return false if sanitized.empty?
      return true if sanitized.start_with?('#', '/', './', '../')
      return false if sanitized.match?(/\A(?:javascript|vbscript|data)\s*:/i)

      if (match = sanitized.match(/\A([a-z][a-z0-9+\-.]*):/i))
        SAFE_URI_SCHEMES.include?(match[1].downcase)
      else
        true
      end
    end

    def prune_unsafe_link_separators(node)
      return unless node

      [node.previous_sibling, node.next_sibling].each do |sibling|
        prune_separator_text_node(sibling)
      end
    end

    def prune_separator_text_node(sibling)
      return unless sibling&.text?

      stripped = sibling.text.strip
      sibling.remove if stripped == '|'
    end

    def parse_integer(raw)
      return nil if raw.nil?

      str = raw.to_s.strip
      return nil unless str.match?(/\A[+-]?\d+\z/)

      str.to_i
    end

    def clean_output(output)
      cleaned = output.gsub(/\r\n?/, "\n")
      cleaned = cleaned.gsub(/[ \t]+\n/, "\n")
      cleaned = Helpers.squeeze_blank_lines_outside_fences(cleaned, max_blank: 2)
      # Trim leading/trailing blank lines but preserve significant trailing spaces
      cleaned = cleaned.gsub(/\A(?:[ \t]*\n)+/, '')
      cleaned.gsub(/(?:\n[ \t]*)+\z/, '')
    end

    def block_like?(node)
      return false unless node.element?

      tag = node.name.downcase
      return true if HEADING_LEVEL.key?(tag)
      return true if BLOCK_CONTAINERS.include?(tag)
      return true if %w[p pre ul ol dl table blockquote hr figcaption].include?(tag)

      false
    end
  end
end
