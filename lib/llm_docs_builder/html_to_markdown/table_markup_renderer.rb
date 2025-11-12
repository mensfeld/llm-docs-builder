# frozen_string_literal: true

module LlmDocsBuilder
  module HtmlToMarkdown
    # Handles conversion of HTML table markup to Markdown table format
    class TableMarkupRenderer
      def initialize(inline_collapser:, block_renderer:)
        @inline_collapser = inline_collapser
        @block_renderer = block_renderer
      end

      # Main entry point for rendering HTML tables to Markdown
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

      private

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
        content = @block_renderer.call(cell.children, depth: 0)
        return '' if content.nil?

        cleaned = content.strip
        return cleaned unless cleaned.empty?

        @inline_collapser.call(cell)
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
        "|#{column_widths.map { |width| '-' * [width + 2, 3].max }.join('|')}|"
      end

      # Table helpers
      def caption_text_for(table_node)
        caption = table_node.at_css('caption')
        text = @inline_collapser.call(caption).strip if caption
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

      def parse_integer(raw)
        return nil if raw.nil?

        str = raw.to_s.strip
        return nil unless str.match?(/\A[+-]?\d+\z/)

        str.to_i
      end
    end
  end
end
