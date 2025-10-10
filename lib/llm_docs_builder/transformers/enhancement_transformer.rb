# frozen_string_literal: true

module LlmDocsBuilder
  module Transformers
    # Transformer for document enhancements
    #
    # Adds helpful features like table of contents and custom instructions
    # to improve LLM navigation and context understanding.
    #
    # @api public
    class EnhancementTransformer
      include BaseTransformer

      # Transform content by adding enhancements
      #
      # @param content [String] markdown content
      # @param options [Hash] transformation options
      # @option options [Boolean] :generate_toc generate table of contents
      # @option options [String] :custom_instruction custom instruction text
      # @option options [Boolean] :remove_blockquotes whether blockquotes are being removed
      # @return [String] transformed content
      def transform(content, options = {})
        result = content.dup

        if options[:custom_instruction]
          result = inject_custom_instruction(result, options[:custom_instruction], options[:remove_blockquotes])
        end
        result = generate_table_of_contents(result) if options[:generate_toc]

        result
      end

      private

      # Generate table of contents from headings
      #
      # @param content [String] markdown content
      # @return [String] content with TOC prepended
      def generate_table_of_contents(content)
        headings = []
        content.scan(/^(#{Regexp.escape('#')}{1,6})\s+(.+)$/) do
          level = ::Regexp.last_match(1).length
          title = ::Regexp.last_match(2).strip

          anchor = title.downcase
                        .gsub(/[^\w\s-]/, '')
                        .gsub(/\s+/, '-')

          headings << { level: level, title: title, anchor: anchor }
        end

        return content if headings.empty?

        toc = ["## Table of Contents\n"]

        headings.each do |heading|
          next if heading[:level] == 1 && headings.first == heading

          indent = '  ' * (heading[:level] - 1)
          toc << "#{indent}- [#{heading[:title]}](##{heading[:anchor]})"
        end

        toc << "\n---\n"

        if content.match(/^#\s+(.+)$/)
          content.sub(/^(#\s+.+\n)/, "\\1\n#{toc.join("\n")}\n")
        else
          "#{toc.join("\n")}\n\n#{content}"
        end
      end

      # Inject custom instruction at document top
      #
      # @param content [String] markdown content
      # @param instruction [String] instruction text
      # @param remove_blockquotes [Boolean] whether to avoid blockquote formatting
      # @return [String] content with instruction prepended
      def inject_custom_instruction(content, instruction, remove_blockquotes = false)
        return content if instruction.nil? || instruction.empty?

        formatted_instruction = if remove_blockquotes
                                  "**AI Context**: #{instruction}\n\n---\n\n"
                                else
                                  "> **AI Context**: #{instruction}\n\n---\n\n"
                                end

        if content.match(/^#\s+(.+?)\n/)
          content.sub(/^(#\s+.+?\n)/, "\\1\n#{formatted_instruction}")
        else
          "#{formatted_instruction}#{content}"
        end
      end
    end
  end
end
