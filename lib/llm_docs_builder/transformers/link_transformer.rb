# frozen_string_literal: true

module LlmDocsBuilder
  module Transformers
    # Transformer for link-related operations
    #
    # Handles expansion of relative links to absolute URLs and conversion of HTML URLs to markdown format.
    #
    # @api public
    class LinkTransformer
      include BaseTransformer

      # Transform links in content
      #
      # @param content [String] markdown content
      # @param options [Hash] transformation options
      # @option options [String] :base_url base URL for expanding relative links
      # @option options [String] :source_path path of the transformed file relative to the
      #   docs root, used to resolve relative links against the file's own directory
      # @option options [Boolean] :convert_urls convert HTML URLs to markdown format
      # @return [String] transformed content
      # @note Code (fenced and indented code blocks, inline code spans) is left unchanged
      def transform(content, options = {})
        outside_code(content) do |result|
          result = expand_relative_links(result, options[:base_url], options[:source_path]) if options[:base_url]
          result = convert_html_urls(result) if options[:convert_urls]
          result = simplify_links(result) if options[:simplify_links]

          result
        end
      end

      private

      # URI schemes that must never be treated as relative paths when expanding
      # links with a base URL (kept in sync with the converter's safe schemes)
      ABSOLUTE_URL_SCHEMES = %w[http https mailto ftp tel].freeze

      # Placeholder that stands in for a protected code fragment
      CODE_PLACEHOLDER = /\u0000(\d+)\u0000/

      # Inline code span: a backtick run closed by a run of the same length, within one paragraph
      INLINE_CODE = /(?<![`\\])(`+)(?!`)(?:(?!\n[ \t]*\n)[^\u0000])+?(?<!`)\1(?!`)/m

      # Opening line of a fenced code block
      FENCE_OPENING = /\A[ \t]*(`{3,}|~{3,})/

      # Blockquote markers at the start of a line
      BLOCKQUOTE_PREFIX = /\A(?: {0,3}> ?)*/

      # Line that starts a list item
      LIST_ITEM = /\A {0,3}(?:[-+*]|\d{1,9}[.)])(?:[ \t]|\s*\z)/

      # Run a transformation on content with code replaced by placeholders, then restore the code
      #
      # @param content [String] markdown content
      # @yieldparam text [String] content with code fragments replaced by placeholders
      # @yieldreturn [String] transformed content
      # @return [String] transformed content with the original code restored
      def outside_code(content)
        codes = []
        protect = lambda do |code|
          codes << code
          "\u0000#{codes.size - 1}\u0000"
        end

        text = protect_code_blocks(content, protect)
        text = text.gsub(INLINE_CODE) { protect.call(::Regexp.last_match(0)) }

        yield(text).gsub(CODE_PLACEHOLDER) { codes[::Regexp.last_match(1).to_i] }
      end

      # Replace fenced and indented code blocks with placeholders
      #
      # Indented lines count as code only after a blank line and outside lists, where they would otherwise be
      # paragraph or list item continuations. Code inside blockquotes is detected after the `>` markers.
      #
      # @param content [String] markdown content
      # @param protect [Proc] stores a code fragment and returns its placeholder
      # @return [String] content with code blocks replaced
      def protect_code_blocks(content, protect)
        out = +''
        code = +''
        fence = nil
        fence_depth = 0
        depth = 0
        in_list = false
        prev_blank = true

        content.each_line do |line|
          quote = line[BLOCKQUOTE_PREFIX]
          body = line.delete_prefix(quote)
          prev_blank ||= quote.count('>') > depth
          depth = quote.count('>')
          fence = nil if depth < fence_depth

          if fence
            code << line
            closing = line.sub(/\A(?: {0,3}> ?){#{fence_depth}}/, '')
            fence = nil if closing.match?(/\A[ \t]*#{Regexp.escape(fence)}#{Regexp.escape(fence[0])}*\s*\z/)
            prev_blank = true
            next
          end

          if !in_list && (prev_blank || !code.empty?) && indented_code?(body)
            code << line
            next
          end

          if (fence = fence_opening(body))
            fence_depth = depth
            code << line
            next
          end

          out << protect_lines(code, protect) << line
          code = +''
          in_list = in_list_after?(body, in_list, prev_blank)
          prev_blank = body.strip.empty?
        end

        out << protect_lines(code, protect)
      end

      # Fence of a line that opens a fenced code block
      #
      # @param line [String] markdown line
      # @return [String, nil] the opening fence, or nil when the line does not open a block
      def fence_opening(line)
        opening = line.match(FENCE_OPENING)
        return unless opening
        return if opening[1].start_with?('`') && opening.post_match.include?('`')

        opening[1]
      end

      # Check whether a line is indented enough to be code
      #
      # @param line [String] markdown line
      # @return [Boolean] true for a non-blank line indented by four spaces or a tab
      def indented_code?(line)
        line.match?(/\A(?: {4}|\t)\s*\S/)
      end

      # Check whether content after a line is still inside a list
      #
      # @param line [String] markdown line
      # @param in_list [Boolean] whether the previous line was inside a list
      # @param prev_blank [Boolean] whether the previous line was blank
      # @return [Boolean] true when the list continues after this line
      def in_list_after?(line, in_list, prev_blank)
        return true if line.match?(LIST_ITEM)
        return in_list if line.strip.empty? || !prev_blank || line.match?(/\A[ \t]/)

        false
      end

      # Replace collected code lines with a placeholder, keeping the final line break
      #
      # @param code [String] collected code lines
      # @param protect [Proc] stores a code fragment and returns its placeholder
      # @return [String] placeholder, or an empty string when there is no code
      def protect_lines(code, protect)
        return '' if code.empty?

        body = code.chomp
        "#{protect.call(body)}#{code.delete_prefix(body)}"
      end

      # Expand relative links to absolute URLs
      #
      # @param content [String] markdown content
      # @param base_url [String] base URL for expansion
      # @param source_path [String, nil] path of the file relative to the docs root
      # @return [String] content with expanded links
      def expand_relative_links(content, base_url, source_path = nil)
        content.gsub(/\[([^\]]+)\]\(([^)]+)\)/) do |match|
          text = ::Regexp.last_match(1)
          url = ::Regexp.last_match(2)
          destination = url.delete_prefix('<')

          if destination.start_with?('http://', 'https://', '//', '#') || absolute_url_scheme?(destination)
            match
          else
            "[#{text}](#{resolve_relative_url(base_url, url, source_path)})"
          end
        end
      end

      # Resolve a relative link target against the base URL
      #
      # Targets starting with `/` are resolved from the base URL itself, other targets from the source
      # file's directory. `./` and `../` segments are normalized. Titles, queries and anchors are kept.
      # Angle-bracket destinations (`<path with spaces>`) are unwrapped and their spaces percent-encoded.
      # A query-only target (`?tab=2`) resolves to the source file itself, as in RFC 3986, with its
      # name percent-encoded.
      #
      # @param base_url [String] base URL for expansion
      # @param target [String] relative link target, optionally followed by a link title
      # @param source_path [String, nil] path of the source file relative to the docs root
      # @return [String] expanded URL
      def resolve_relative_url(base_url, target, source_path)
        url, title = target.match(/\A(.*?)(\s+(?:"[^"]*"|'[^']*'))?\z/m).captures
        url = url[/\A<(.*)>\z/m, 1]&.gsub(' ', '%20') || url
        path, suffix = url.match(/\A([^?#]*)(.*)\z/m).captures
        query_only = source_path && path.empty? && suffix.start_with?('?')
        path = ERB::Util.url_encode(File.basename(source_path)) if query_only
        source_dir = source_path ? File.dirname(source_path) : '.'
        origin = base_url[%r{\A[^:/?#]+://[^/?#]*}].to_s
        base_path = base_url.delete_prefix(origin)
        dir = path.start_with?('/') ? base_path : File.join(base_path, source_dir)

        "#{origin}#{normalize_path("#{dir}/#{path}")}#{suffix}#{title}"
      end

      # Normalize `.`, `..` and empty segments of a path
      #
      # @param path [String] path to normalize
      # @return [String] normalized path, with its trailing slash kept
      def normalize_path(path)
        normalized = Pathname.new(path).cleanpath.to_s
        normalized += '/' if path.match?(%r{/\.{0,2}\z}) && !normalized.end_with?('/')
        normalized
      end

      # Check whether a link target uses a known absolute URI scheme
      #
      # @param url [String] link target
      # @return [Boolean] true when the target already carries its own scheme
      def absolute_url_scheme?(url)
        scheme = url.split(':', 2).first.to_s
        ABSOLUTE_URL_SCHEMES.include?(scheme)
      end

      # Convert HTML URLs to markdown format
      #
      # @param content [String] markdown content
      # @return [String] content with converted URLs
      def convert_html_urls(content)
        content.gsub(%r{https?://[^\s<>]+\.html?(?=[)\s]|$)}) do |url|
          url.sub(/\.html?$/, '.md')
        end
      end

      # Simplify verbose link text
      #
      # @param content [String] markdown content
      # @return [String] content with simplified links
      def simplify_links(content)
        content.gsub(/\[([^\]]+)\]\(([^)]+)\)/) do
          text = ::Regexp.last_match(1)
          url = ::Regexp.last_match(2)

          simplified_text = text
                            .gsub(/^(click here to|see|read more about|check out|visit)\s+(the\s+)?/i, '')
                            .gsub(/\s+(here|documentation|docs)$/i, '')
                            .strip

          simplified_text = text if simplified_text.empty?

          "[#{simplified_text}](#{url})"
        end
      end
    end
  end
end
