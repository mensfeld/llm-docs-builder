# frozen_string_literal: true

module LlmDocsBuilder
  module Transformers
    # Normalizes headings to include hierarchical context
    #
    # Transforms markdown headings to include parent context, making each section
    # self-contained for RAG systems. This is particularly useful when documents
    # are chunked and retrieved independently.
    #
    # @example Basic heading normalization
    #   # Configuration
    #   ## Consumer Settings
    #   ### auto_offset_reset
    #
    #   Becomes:
    #   # Configuration
    #   ## Configuration / Consumer Settings
    #   ### Configuration / Consumer Settings / auto_offset_reset
    #
    # @api public
    class HeadingTransformer
      include BaseTransformer

      # Transform content by normalizing heading hierarchy
      #
      # Parses markdown headings and adds parent context to each heading,
      # making sections self-documenting when retrieved independently.
      #
      # @param content [String] markdown content to transform
      # @param options [Hash] transformation options
      # @option options [Boolean] :normalize_headings enable heading normalization
      # @option options [String] :heading_separator separator between heading levels (default: ' / ')
      # @return [String] transformed content with normalized headings
      def transform(content, options = {})
        return content unless options[:normalize_headings]

        separator = options[:heading_separator] || ' / '
        heading_stack = []
        lines = content.lines
        in_code_block = false

        transformed_lines = lines.map do |line|
          # Track code block boundaries (fenced code blocks with ``` or ~~~)
          if line.match?(/^(```|~~~)/)
            in_code_block = !in_code_block
            next line
          end

          # Skip heading processing if inside code block
          next line if in_code_block

          # Match markdown headings (1-6 hash symbols followed by space and text)
          heading_match = line.match(/^(#+)\s+(.+)$/)

          if heading_match && heading_match[1].count('#').between?(1, 6)
            level = heading_match[1].count('#')
            title = heading_match[2].strip

            # Update heading stack to current level
            heading_stack = heading_stack[0...level - 1]
            heading_stack << title

            # Build hierarchical heading
            if level == 1
              # H1 stays as-is (top level)
              line
            else
              # H2+ gets parent context
              hierarchical_title = heading_stack.join(separator)
              "#{'#' * level} #{hierarchical_title}\n"
            end
          else
            line
          end
        end

        transformed_lines.join
      end
    end
  end
end
