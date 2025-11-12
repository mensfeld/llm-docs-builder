# frozen_string_literal: true

module LlmDocsBuilder
  module HtmlToMarkdown
    # Converts <figure> elements that actually contain syntax-highlighted code back into fenced Markdown.
    class FigureCodeBlockRenderer
      GENERIC_CODE_CLASSES = %w[highlight code main gutter numbers line-numbers line-number line wrap table].freeze

      attr_reader :code_block_node

      def initialize(element, inline_collapser:, fence_calculator:)
        @element = element
        @inline_collapser = inline_collapser
        @fence_calculator = fence_calculator
      end

      def render
        @code_block_node = nil
        return unless code_figure?

        lines = extract_figure_code_lines
        return if lines.empty?

        language = detect_code_language
        caption = caption_text
        info_string = [language, caption].compact.reject(&:empty?).join(' ')
        code_body = lines.join("\n")
        fence = fence_calculator.call(code_body)
        opening_fence = info_string.empty? ? fence : "#{fence}#{info_string}"
        "#{opening_fence}\n#{code_body}\n#{fence}"
      end

      private

      attr_reader :element, :inline_collapser, :fence_calculator

      def caption_text
        caption_node = element.at_css('figcaption')
        return if caption_node.nil?

        inline_collapser.call(caption_node)
      end

      def code_figure?
        class_tokens(element).any? { |token| token.casecmp('code').zero? }
      end

      def extract_figure_code_lines
        pre = element.at_css('td.main pre') ||
              element.at_css('td:not(.line-numbers) pre') ||
              element.at_css('div.highlight pre') ||
              element.at_css('pre')
        @code_block_node = pre
        return [] unless pre

        lines =
          if pre.css('.line').any?
            pre.css('.line').map { |line| extract_code_line_text(line) }
          else
            raw = pre.at_css('code') ? pre.at_css('code').text : pre.text
            raw.to_s.gsub(/\r\n?/, "\n").split("\n", -1)
          end

        clean_code_lines(lines)
      end

      def extract_code_line_text(line_node)
        text = line_node.xpath('.//text()').map(&:text).join
        text = text.tr("\u00a0", ' ')
        text.gsub(/\r\n?/, '').rstrip
      end

      def clean_code_lines(lines)
        sanitized = lines.map { |line| line.to_s.gsub(/\r\n?/, "\n") }
        sanitized.shift while sanitized.first&.strip&.empty?
        sanitized.pop while sanitized.last&.strip&.empty?
        sanitized
      end

      def detect_code_language
        candidates = [
          element.at_css('code'),
          element.at_css('pre'),
          element.at_css('td.main'),
          element.at_css('div.highlight'),
          element
        ].compact
        candidates.concat(element.css('[data-language], [data-lang], [lang], [class]'))

        candidates.each do |node|
          language = extract_language_from_node(node)
          return language unless language.nil? || language.empty?
        end

        nil
      end

      def extract_language_from_node(node)
        %w[data-language data-lang lang].each do |attr|
          value = node[attr]
          return value.to_s.strip unless value.nil? || value.to_s.strip.empty?
        end

        class_attr = node['class']
        return nil if class_attr.nil? || class_attr.strip.empty?

        tokens = class_tokens(node)
        tokens.each do |token|
          next if token.empty?

          if (match = token.match(/\A(?:language|lang)-(.*)\z/i))
            candidate = match[1].to_s.strip
            return candidate unless candidate.empty?
          end

          lowered = token.downcase
          next if GENERIC_CODE_CLASSES.include?(lowered)

          return token
        end

        nil
      end

      def class_tokens(node)
        (node['class'] || '').split(/\s+/).reject(&:empty?)
      end
    end
  end
end
