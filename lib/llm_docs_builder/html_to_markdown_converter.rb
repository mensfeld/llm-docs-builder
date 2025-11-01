# frozen_string_literal: true

require 'html_to_markdown'
require 'cgi'

module LlmDocsBuilder
  # Wrapper around html-to-markdown gem to convert HTML fragments to markdown
  class HtmlToMarkdownConverter
    DEFAULT_OPTIONS = {
      heading_style: :atx,
      wrap: true
    }.freeze

    # Converts HTML to markdown using the html-to-markdown gem
    #
    # @param html [String] input HTML
    # @return [String] cleaned markdown
    def convert(html)
      return '' if html.nil? || html.strip.empty?

      @code_blocks = []
      @ordered_list_sequences = []

      processed_html = preprocess_html(html.to_s)
      markdown = HtmlToMarkdown.convert(processed_html, **DEFAULT_OPTIONS)
      markdown = postprocess_markdown(markdown)

      clean_output(markdown)
    end

    private

    def preprocess_html(html)
      # Detect presence of nested lists for later indentation fix
      @has_nested_list = html.match?(%r{<li[^>]*>(?:[^<]|<(?!/?ul\b))*<ul}mi)

      # Extract ordered list sequences with custom starts/values for later renumbering
      html.scan(%r{<ol([^>]*)>([\s\S]*?)</ol>}mi) do |ol_attrs, inner|
        initial_start = extract_numeric_attr(ol_attrs, 'start') || 1
        start_index = initial_start
        nums = []
        has_value_override = inner.match?(/<li[^>]*\bvalue\s*=\s*['"][^'"]+['"]/i)

        inner.scan(%r{<li([^>]*)>([\s\S]*?)</li>}mi) do |li_attrs, _content|
          value_attr = extract_numeric_attr(li_attrs, 'value')
          if value_attr
            nums << value_attr
            start_index = value_attr + 1
          else
            nums << start_index
            start_index += 1
          end
        end

        @ordered_list_sequences << nums if has_value_override || initial_start != 1
      end

      # Preserve <br> as explicit line breaks using placeholders that we convert after markdown
      html = html.gsub(%r{<\s*br\s*/?>}i, '<span data-llmdocs-br>__LLM_BR__</span>')

      # Preserve pre/code blocks -> fenced code blocks via placeholders
      index = 0
      html.gsub(%r{<pre[^>]*>\s*<code[^>]*>([\s\S]*?)</code>\s*</pre>}mi) do
        content = Regexp.last_match(1)
        @code_blocks << CGI.unescapeHTML(content.to_s)
        placeholder = "__LLM_CODE_#{index}__"
        index += 1
        %(<div data-llmdocs-code>#{placeholder}</div>)
      end
    end

    def postprocess_markdown(markdown)
      output = markdown.dup

      # Convert BR placeholders to newlines
      output.gsub!(/\s*__LLM_BR__\s*/, "\n")

      # Replace code placeholders with fenced code blocks
      @code_blocks&.each_with_index do |raw, i|
        code = raw.to_s.gsub(/\r\n?/, "\n").delete_prefix("\n").rstrip
        fenced = "```\n#{code}\n```"
        output.gsub!("__LLM_CODE_#{i}__", fenced)
      end

      # Drop link titles added by gem: [text](url "title") -> [text](url)
      output.gsub!(/\]\(([^)\s]+)[ \t]+"[^"]*"\)/, '](\1)')

      # Fix nested list indentation for one-level nested unordered lists
      if @has_nested_list
        lines = output.split("\n", -1)
        applied = false
        lines.each_with_index do |_line, idx|
          next if applied
          next unless idx.positive?

          if lines[idx - 1].start_with?('- ') && lines[idx].start_with?('- ')
            lines[idx] = "  #{lines[idx]}"
            applied = true
          end
        end
        output = lines.join("\n")
      end

      # Renumber ordered lists to respect <ol start> and <li value>
      unless @ordered_list_sequences.empty?
        lines = output.split("\n", -1)
        search_pos = 0

        @ordered_list_sequences.each do |nums|
          found_index = nil
          i = search_pos
          while i < lines.length
            line = lines[i]
            if line =~ /^\s*\d+\.\s/
              # Determine run length
              j = i
              run_len = 0
              while j < lines.length && lines[j] =~ /^\s*\d+\.\s/
                run_len += 1
                j += 1
              end

              if run_len >= nums.length
                first_num = lines[i][/^\s*(\d+)\.\s/, 1].to_i
                if first_num == nums.first
                  found_index = i
                  break
                end
              end
              i = j
            else
              i += 1
            end
          end

          next unless found_index

          nums.each_with_index do |n, offset|
            idx = found_index + offset
            lines[idx] = lines[idx].sub(/\A(\s*)\d+\.\s/, "\\1#{n}. ")
          end
          search_pos = found_index + nums.length
        end

        output = lines.join("\n")
      end

      output
    end

    def extract_numeric_attr(attrs, name)
      return nil unless attrs

      if (m = attrs.match(/\b#{Regexp.escape(name)}\s*=\s*['"]?(\d+)['"]?/i))
        m[1].to_i
      end
    end

    def clean_output(output)
      cleaned = output.to_s.gsub(/\r\n?/, "\n")
      cleaned = cleaned.gsub(/[ \t]+\n/, "\n")
      cleaned = cleaned.gsub(/\n{3,}/, "\n\n")
      cleaned.strip
    end
  end
end
