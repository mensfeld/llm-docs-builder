# frozen_string_literal: true

module LlmDocsBuilder
  # Detects whether input should be treated as HTML and related snippet checks
  class HtmlDetector
    # Detect if loaded content is HTML instead of markdown
    #
    # @param content [String] raw content
    # @param snippet [String, nil] optional precomputed snippet
    # @return [Boolean]
    def html_content?(content, snippet = detection_snippet(content))
      return false unless html_content_snippet?(snippet)

      full_html_document?(content)
    end

    # Prepare a snippet of content for HTML detection by removing leading whitespace
    # and build metadata comments.
    #
    # @param content [String]
    # @return [String, nil]
    def detection_snippet(content)
      return unless content

      snippet = content.lstrip
      return unless snippet

      comment_prefix = /\A<!--.*?-->\s*/m
      # Remote docs often include build metadata comments; skip them before tag detection.
      return '' if snippet.empty? while snippet.sub!(comment_prefix, '')

      snippet.lstrip[0, 500]
    end

    # Determine whether a snippet should be treated as HTML.
    #
    # @param snippet [String, nil]
    # @return [Boolean]
    def html_content_snippet?(snippet)
      return false unless snippet && !snippet.empty?
      return false if markdown_heading_snippet?(snippet)

      html_candidate_snippet?(snippet)
    end

    # Determine whether a snippet appears to start with HTML markup.
    #
    # @param snippet [String]
    # @return [Boolean]
    def html_candidate_snippet?(snippet)
      snippet.match?(/\A<\s*(?:!DOCTYPE\s+html|html\b|body\b|head\b|article\b|section\b|main\b|p\b|div\b|table\b|thead\b|tbody\b|tr\b|td\b|th\b|meta\b|link\b|h[1-6]\b|ul\b|ol\b|li\b|blockquote\b)/i)
    end

    # Check if the full document should be treated as HTML by parsing it and
    # ensuring we do not observe unwrapped markdown constructs like plain text or lists.
    #
    # @param content [String]
    # @return [Boolean]
    def full_html_document?(content)
      document = Nokogiri::HTML::Document.parse(content)
      body = document.at('body')

      return false unless body
      return false if document.xpath('/text()').any? { |node| meaningful_text?(node.text) }

      body.xpath('./text()').each do |node|
        text = node.text
        next unless meaningful_text?(text)

        return false unless allow_inline_body_text?(content, text)
      end

      true
    rescue Nokogiri::XML::SyntaxError
      false
    end

    def meaningful_text?(text)
      return false if text.nil?

      stripped = text.strip
      stripped.match?(/\S/)
    end

    def markdown_like_text?(text)
      return false if text.nil?
      return true if markdown_heading_snippet?(text)

      text.each_line do |line|
        trimmed = line.lstrip
        next if trimmed.empty?
        next if trimmed.start_with?('<')

        return true if trimmed.match?(/\A[*+-]\s+\S/)
        return true if trimmed.match?(/\A\d+\.\s+\S/)
        return true if trimmed.match?(/\A>\s+\S/)
        return true if trimmed.start_with?('```', '~~~')
        return true if trimmed.strip.match?(/\A(?:-{3,}|_{3,}|={3,})\z/)
      end

      false
    end

    def allow_inline_body_text?(content, text)
      return false if markdown_like_text?(text)

      html_with_body_wrapper?(content)
    end

    def html_with_body_wrapper?(content)
      content.match?(/<\s*!DOCTYPE\s+html/i) ||
        content.match?(/<\s*html\b/i) ||
        content.match?(/<\s*body\b/i)
    end

    # Detect whether the snippet represents a table fragment we should preserve.
    #
    # @param snippet [String, nil]
    # @return [Boolean]
    def table_fragment?(snippet)
      return false unless snippet && !snippet.empty?

      snippet.match?(/\A<\s*(?:table|thead|tbody|tr|td|th)\b/i)
    end

    # Detect common markdown heading syntax within the snippet.
    #
    # @param snippet [String]
    # @return [Boolean]
    def markdown_heading_snippet?(snippet)
      snippet.each_line do |line|
        trimmed = line.lstrip
        next if trimmed.empty?
        next if trimmed.start_with?('<')

        return true if trimmed.match?(/\A#+\s+/)
      end

      false
    end
  end
end
