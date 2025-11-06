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

      return render_table(element) if tag == 'table'

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
      when *BLOCK_CONTAINERS
        # Transparent block container: render its children as blocks.
        # If the container only has inline/text content, render that inline instead.
        blocks = render_blocks(element.children, depth: depth)
        if blocks.strip.empty?
          collapsed_inline_for(element)
        else
          blocks
        end
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
      fence_length = [3, (code.scan(/`+/).map(&:length).max || 0) + 1].max
      fence = '`' * fence_length
      "#{fence}\n#{code}\n#{fence}"
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

    def render_table(table_node)
      return table_node.to_html if table_contains_nested_tables?(table_node)
      return render_table_with_rowspan_cells(table_node) if table_contains_rowspan_cells?(table_node)
      return render_table_with_colspan_cells(table_node) if table_contains_colspan_cells?(table_node)

      caption_text = caption_text_for(table_node)

      rows = table_node.css('tr').map do |row|
        cells = row.element_children.select { |child| %w[th td].include?(child.name.downcase) }
        next if cells.empty?

        header_candidate = row.ancestors('thead').any? ||
                           cells.all? { |cell| cell.name.casecmp('th').zero? }

        {
          header: header_candidate,
          values: cells.map { |cell| render_table_cell(cell) }
        }
      end.compact
      return '' if rows.empty?

      header_index = rows.find_index { |row| row[:header] }

      if header_index
        header_values = rows[header_index][:values]
        data_values = rows.each_with_index.filter_map do |row, index|
          next if index == header_index

          row[:values]
        end
      else
        header_values = rows.first[:values]
        data_values = rows.drop(1).map { |row| row[:values] }
      end

      column_count = [header_values.length, data_values.map(&:length).max || 0].max
      column_count = 1 if column_count.zero?

      header = pad_table_row(header_values, column_count)
      data_rows = data_values.map { |row| pad_table_row(row, column_count) }

      header_cells = header.map { |value| table_cell_data(value) }
      data_cells = data_rows.map { |row| row.map { |value| table_cell_data(value) } }

      column_specs = compute_table_column_specs(header_cells, data_cells)
      column_widths = column_specs.map { |spec| spec[:width] }

      lines = []
      lines.concat(format_table_row(header_cells, column_specs))
      lines << render_table_separator(column_widths)
      data_cells.each do |row_cells|
        lines.concat(format_table_row(row_cells, column_specs))
      end

      table_markdown = lines.join("\n")

      with_optional_caption(caption_text, table_markdown)
    end

    def render_table_with_rowspan_cells(table_node)
      caption_text = caption_text_for(table_node)

      span_slots = []
      rows = []

      table_node.css('tr').each do |row|
        cells = row.element_children.select { |child| %w[th td].include?(child.name.downcase) }
        next if cells.empty?

        header_candidate = row.ancestors('thead').any? ||
                           cells.all? { |cell| cell.name.casecmp('th').zero? }

        expanded_cells = expand_row_for_rowspans(cells, span_slots)
        rows << { header: header_candidate, cells: expanded_cells }
      end

      return table_node.to_html if rows.empty?

      column_count = rows.map { |row| row[:cells].length }.max || 1
      column_count = 1 if column_count.zero?

      header_index = find_header_index(rows, default: 0)

      header_values = pad_table_row(rows[header_index][:cells], column_count)
      header_lines = format_rowspan_row_text(header_values).to_s.split("\n", -1)
      header_lines = [''] if header_lines.empty?
      header_lines.map! { |line| line.empty? ? ' ' : line }

      header_cells = header_values.map { |value| table_cell_data(value) }
      column_widths = column_widths_from_cells(header_cells)

      lines = header_lines.map { |line| format_bordered_row_content(line) }
      lines << render_table_separator(column_widths)

      rows.each_with_index do |row, index|
        next if index == header_index

        padded_cells = pad_table_row(row[:cells], column_count)
        row_lines = format_rowspan_row_text(padded_cells).to_s.split("\n", -1)
        row_lines = [''] if row_lines.empty?

        row_lines.each do |line|
          display = line.empty? ? ' ' : line
          lines << format_bordered_row_content(display)
        end
      end

      table_markdown = lines.join("\n")

      with_optional_caption(caption_text, table_markdown)
    end

    def render_table_with_colspan_cells(table_node)
      caption_text = caption_text_for(table_node)

      rows = table_node.css('tr').map do |row|
        cells = row.element_children.select { |child| %w[th td].include?(child.name.downcase) }
        next if cells.empty?

        header_candidate = row.ancestors('thead').any? ||
                           cells.all? { |cell| cell.name.casecmp('th').zero? }

        values = cells.map { |cell| render_table_cell(cell) }
        # Escape literal pipes in each cell to avoid creating bogus columns when joined
        escaped_values = values.map { |v| sanitize_table_cell_line(v, escape_pipes: true) }
        text = escaped_values.join(' | ').strip

        {
          header: header_candidate,
          values: values,
          text: text
        }
      end.compact
      return table_node.to_html if rows.empty?

      header_index = find_header_index(rows, default: 0)
      header = rows[header_index]
      data_rows = rows.each_with_index.filter_map { |row, index| index == header_index ? nil : row }

      column_count = rows.map { |row| row[:values].length }.max || 1
      column_count = 1 if column_count.zero?

      header_values = pad_table_row(header[:values] || [], column_count)
      header_cells = header_values.map { |value| table_cell_data(value) }
      column_widths = column_widths_from_cells(header_cells)

      lines = []
      lines << format_bordered_row_content(header[:text])
      lines << render_table_separator(column_widths)
      data_rows.each { |row| lines << format_bordered_row_content(row[:text]) }

      table_markdown = lines.join("\n")

      with_optional_caption(caption_text, table_markdown)
    end

    def expand_row_for_rowspans(cells, span_slots)
      row_cells = []
      column = 0

      cells.each do |cell|
        while span_slots[column].to_i.positive?
          row_cells << ''
          span_slots[column] = span_slots[column].to_i - 1
          span_slots[column] = nil if span_slots[column].to_i <= 0
          column += 1
        end

        value = render_table_cell(cell)
        colspan = parse_integer(cell['colspan']) || 1
        colspan = 1 if colspan <= 0
        rowspan = parse_integer(cell['rowspan']) || 1
        rowspan = 1 if rowspan <= 0

        colspan.times do |offset|
          row_cells << (offset.zero? ? value : '')
          target_index = column + offset
          span_slots[target_index] = (rowspan - 1 if rowspan > 1)
        end

        column += colspan
      end

      while span_slots[column].to_i.positive?
        row_cells << ''
        span_slots[column] = span_slots[column].to_i - 1
        span_slots[column] = nil if span_slots[column].to_i <= 0
        column += 1
      end

      row_cells
    end

    def format_rowspan_row_text(cells)
      values =
        if cells.is_a?(Array)
          cells.map(&:to_s)
        else
          # Fallback: split a pre-joined string if encountered
          cells.to_s.split(' | ')
        end

      # Escape literal pipes per cell so row assembly with ' | ' doesn't introduce extra columns
      safe_values = values.map { |value| sanitize_table_cell_line(value, escape_pipes: true) }

      split_values =
        safe_values.map do |value|
          segments = value.gsub(/\r\n?/, "\n").split("\n")
          segments = [''] if segments.empty?
          segments
        end

      max_lines = split_values.map(&:length).max || 0
      return '' if max_lines.zero?

      column_widths =
        split_values.map do |segments|
          segments.map(&:length).max || 0
        end

      lines = Array.new(max_lines) do |row_index|
        row_values =
          split_values.each_with_index.map do |segments, column_index|
            segment = segments[row_index] || ''
            width = column_widths[column_index]
            if width.positive? && !segment.empty?
              segment.ljust(width)
            else
              segment
            end
          end

        row_values.join(' | ')
      end

      lines.join("\n")
    end

    def render_table_cell(cell)
      content = render_blocks(cell.children, depth: 0)
      return '' if content.nil?

      cleaned = content.strip
      return cleaned unless cleaned.empty?

      collapsed_inline_for(cell)
    end

    def table_cell_data(value)
      text = value.to_s
      return { lines: [''], pipe_split: false } if text.empty?

      pipe_split = false

      lines =
        text
        .gsub(/\r\n?/, "\n")
        .split("\n")
        .flat_map do |line|
          segments, split_flag = split_table_cell_line(line)
          pipe_split ||= split_flag
          segments
        end

      lines.reject! { |segment| segment.strip.empty? }
      lines = [''] if lines.empty?

      { lines: lines, pipe_split: pipe_split }
    end

    def split_table_cell_line(line)
      return [[''], false] if line.nil? || line.empty?

      # We always treat a cell line as a single segment and escape literal pipes
      # that are outside of code spans. This keeps column integrity intact.
      sanitized_line = sanitize_table_cell_line(line, escape_pipes: true)
      [[sanitized_line], false]
    end

    def sanitize_table_cell_line(text, escape_pipes: false)
      raw = text.to_s
      return '' if raw.empty?

      sanitized = +''
      index = 0
      length = raw.length
      inside_code = false
      fence_length = 0

      while index < length
        char = raw[index]

        if char == '\\'
          sanitized << '\\\\'
          index += 1
          if index < length
            sanitized << raw[index]
            index += 1
          end
          next
        end

        if char == '`'
          run_length = 1
          run_length += 1 while index + run_length < length && raw[index + run_length] == '`'

          sanitized << ('`' * run_length)
          index += run_length

          if inside_code
            inside_code = false if run_length == fence_length
            fence_length = 0 unless inside_code
          else
            inside_code = true
            fence_length = run_length
          end

          next
        end

        if char == '|' && escape_pipes && !inside_code
          sanitized << '\\|'
          index += 1
          next
        end

        sanitized << char
        index += 1
      end

      sanitized.strip
    end

    def table_contains_nested_tables?(table_node)
      table_node.css('table').any?
    end

    def table_contains_rowspan_cells?(table_node)
      table_node.css('td[rowspan], th[rowspan]').any? do |cell|
        span_value_significant?(cell['rowspan'])
      end
    end

    def table_contains_colspan_cells?(table_node)
      table_node.css('td[colspan], th[colspan]').any? do |cell|
        span_value_significant?(cell['colspan'])
      end
    end

    def span_value_significant?(raw_value)
      return false if raw_value.nil?

      value = raw_value.to_s.strip
      return true if value.empty?
      return false if value == '1'

      integer = value.to_i
      return true if integer > 1

      integer <= 0 || value != integer.to_s
    end

    def pad_table_row(values, length)
      padded = values.nil? ? [] : values.dup
      padded = [] if padded.nil?

      padded << '' while padded.length < length

      padded[0, length]
    end

    def compute_table_column_specs(header_cells, data_cells)
      column_count = header_cells.length

      column_count.times.map do |index|
        header_cell = header_cells[index] || { lines: [''], pipe_split: false }
        column_cells = data_cells.map { |row| row[index] || { lines: [''], pipe_split: false } }

        header_width = header_cell[:lines].map(&:length).max || 0
        content_width = column_cells.map { |cell| cell[:lines].map(&:length).max || 0 }.max || 0

        requires_padding =
          ([header_cell] + column_cells).any? do |cell|
            cell[:lines].length > 1 && !cell[:pipe_split]
          end

        width =
          if requires_padding
            [header_width, content_width].max
          else
            header_width
          end
        width = [width, 1].max

        { width: width, pad: requires_padding }
      end
    end

    def format_table_row(row_cells, column_specs)
      row_height = row_cells.map { |cell| cell[:lines].length }.max || 0
      row_height = 1 if row_height.zero?

      rows = []

      row_height.times do |line_index|
        values = column_specs.each_index.map do |column_index|
          cell = row_cells[column_index] || { lines: [''], pipe_split: false }
          line = cell[:lines][line_index] || ''
          spec = column_specs[column_index]
          spec[:pad] ? pad_table_cell_line(line, spec[:width]) : line.to_s
        end

        next if values.all? { |value| value.strip.empty? }

        rows << "| #{values.join(' | ')} |"
      end

      if rows.empty?
        placeholder = column_specs.map { |spec| ' ' * spec[:width] }.join(' | ')
        ["| #{placeholder} |"]
      else
        rows
      end
    end

    def pad_table_cell_line(text, width)
      value = text.to_s
      width <= 0 ? value : value.ljust(width)
    end

    def render_table_separator(column_widths)
      '|' + column_widths.map { |width| '-' * [width + 2, 3].max }.join('|') + '|'
    end

    # Table helpers
    def caption_text_for(table_node)
      caption = table_node.at_css('caption')
      text = collapsed_inline_for(caption).strip if caption
      text = nil if text.nil? || text.empty?
      text
    end

    def with_optional_caption(caption_text, table_markdown)
      caption_text ? "#{caption_text}\n\n#{table_markdown}" : table_markdown
    end

    def find_header_index(rows, default: nil)
      idx = rows.find_index { |row| row[:header] }
      idx.nil? ? default : idx
    end

    def format_bordered_row_content(content)
      value = content.to_s
      value = ' ' if value.empty?
      "| #{value} |"
    end

    def column_widths_from_cells(cells)
      cells.map do |cell|
        width = cell[:lines].map(&:length).max || 0
        [width, 1].max
      end
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
