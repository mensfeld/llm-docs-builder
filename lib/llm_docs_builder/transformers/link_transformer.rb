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
          if options[:base_url]
            result = expand_relative_links(
              result, options[:base_url], options[:source_path], convert_urls: options[:convert_urls]
            )
          end
          result = convert_html_urls(result, convert_definitions: !options[:base_url]) if options[:convert_urls]
          result = simplify_links(result) if options[:simplify_links]

          result
        end
      end

      private

      # A link target with a URI scheme is never a relative path
      URI_SCHEME_PATTERN = /\A[a-z][a-z0-9+.-]*:/i
      private_constant :URI_SCHEME_PATTERN

      # Placeholder that stands in for a protected code fragment; a code block's ends with `b`
      CODE_PLACEHOLDER = /\u0000(\d+)b?\u0000/

      # Inline code span: a backtick run closed by a run of the same length, within one paragraph
      INLINE_CODE = /(?<![`\\])(`+)(?!`)(?:(?!\n[ \t]*\n)[^\u0000])+?(?<!`)\1(?!`)/m

      # Opening line of a fenced code block
      FENCE_OPENING = /\A[ \t]*(`{3,}|~{3,})/

      # Blockquote markers at the start of a line
      BLOCKQUOTE_PREFIX = /\A(?: {0,3}> ?)*/

      # Line that starts a list item
      LIST_ITEM = /\A {0,3}(?:[-+*]|\d{1,9}[.)])(?:[ \t]|\s*\z)/

      # Contents of a bracket pair in a link text: plain text, images and brackets that do not open a link
      # (links do not nest)
      BRACKET_CONTENT_PATTERN = /(?:[^\[\]]|!\[[^\[\]]*\]|\[[^\[\]]*\](?!\())*/

      # Part of a link text: brackets in it may be nested up to two levels deep (e.g. a linked image)
      LINK_TEXT_PART_PATTERN = /[^\[\]]|!\[#{BRACKET_CONTENT_PATTERN}\]|\[#{BRACKET_CONTENT_PATTERN}\](?!\()/

      # Link destination; it never runs into protected code, only its title may contain it
      LINK_DESTINATION_PATTERN = /\(([^)\u0000]+(?:\s+(?:"[^")]*"|'[^')]*'))?)\)/

      # Inline link
      LINK_PATTERN = /\[((?:#{LINK_TEXT_PART_PATTERN})+)\]#{LINK_DESTINATION_PATTERN}/

      # Inline link or image inside a link text, where an image may have no alt text (`[![](badge.svg)](url)`)
      NESTED_LINK_PATTERN = /\[((?:#{LINK_TEXT_PART_PATTERN})*)\]#{LINK_DESTINATION_PATTERN}/

      # Link reference definition line (`[id]: target "title"`): its label, destination and the rest of the line.
      # Footnote definitions (`[^1]: text`) are not link reference definitions.
      REFERENCE_DEFINITION_PATTERN = /
        ^((?:\ {0,3}>\ ?)*\ {0,3}\[(?!\^)(?:[^\[\]\\\n]|\\.)+\]:[ \t]*)
        (<[^<>\n]*>|[^\s<\u0000][^\s\u0000]*)
        ((?:[ \t]+(?:"[^"\n]*"|'[^'\n]*'|\([^()\n]*\)))?[ \t\r]*)$
      /x

      # Consecutive link reference definition lines
      REFERENCE_DEFINITIONS_PATTERN = /#{REFERENCE_DEFINITION_PATTERN}(?:\n#{REFERENCE_DEFINITION_PATTERN})*/

      # Line that link reference definitions may follow: a blank line, an ATX heading, a thematic break or a code
      # block. A definition cannot interrupt a paragraph.
      REFERENCE_DEFINITIONS_PRECEDING_LINE_PATTERN = /
        (?:\ {0,3}>\ ?)*
        (?:
          [ \t]* |
          \ {0,3}\#{1,6}(?:[ \t][^\n]*)? |
          \ {0,3}(?:(?:\*[ \t]*){3,}|(?:-[ \t]*){3,}|(?:_[ \t]*){3,}) |
          \u0000\d+b\u0000[ \t]*
        )\r?
      /x

      # Definitions on the first or second line of the content
      LEADING_REFERENCE_DEFINITIONS_PATTERN =
        /\A(?:#{REFERENCE_DEFINITIONS_PRECEDING_LINE_PATTERN}\n)?\K#{REFERENCE_DEFINITIONS_PATTERN}/

      # Definitions from the third line on, so that they never overlap the leading ones. Kept apart from the leading
      # pattern: an `\A` alternative here would make the regex try every position of the content.
      FOLLOWING_REFERENCE_DEFINITIONS_PATTERN =
        /\n#{REFERENCE_DEFINITIONS_PRECEDING_LINE_PATTERN}\n\K#{REFERENCE_DEFINITIONS_PATTERN}/

      private_constant :CODE_PLACEHOLDER, :INLINE_CODE, :FENCE_OPENING, :BLOCKQUOTE_PREFIX, :LIST_ITEM,
        :BRACKET_CONTENT_PATTERN, :LINK_TEXT_PART_PATTERN, :LINK_DESTINATION_PATTERN, :LINK_PATTERN,
        :NESTED_LINK_PATTERN, :REFERENCE_DEFINITION_PATTERN, :REFERENCE_DEFINITIONS_PATTERN,
        :REFERENCE_DEFINITIONS_PRECEDING_LINE_PATTERN, :LEADING_REFERENCE_DEFINITIONS_PATTERN,
        :FOLLOWING_REFERENCE_DEFINITIONS_PATTERN

      # Run a transformation on content with code replaced by placeholders, then restore the code
      #
      # @param content [String] markdown content
      # @yieldparam text [String] content with code fragments replaced by placeholders
      # @yieldreturn [String] transformed content
      # @return [String] transformed content with the original code restored
      def outside_code(content)
        codes = []
        protect = lambda do |code, block: false|
          codes << code
          "\u0000#{codes.size - 1}#{'b' if block}\u0000"
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
        "#{protect.call(body, block: true)}#{code.delete_prefix(body)}"
      end

      # Expand relative links and link reference definitions to absolute URLs
      #
      # @param content [String] markdown content
      # @param base_url [String] base URL for expansion
      # @param source_path [String, nil] path of the file relative to the docs root
      # @param convert_urls [Boolean] also convert HTML targets of link reference definitions to markdown, so the
      #   definitions are scanned only once
      # @return [String] content with expanded links
      def expand_relative_links(content, base_url, source_path = nil, convert_urls: false)
        result = expand_links_matching(content, LINK_PATTERN, base_url, source_path)

        rewrite_reference_definitions(result) do |target|
          expanded = expand_target(target, base_url, source_path)
          convert_urls ? convert_html_target(expanded) : expanded
        end
      end

      # Rewrite the destinations of link reference definitions
      #
      # @param content [String] markdown content
      # @yieldparam target [String] destination of a definition
      # @yieldreturn [String] new destination
      # @return [String] content with rewritten definitions
      def rewrite_reference_definitions(content)
        return content unless content.include?(']:')

        rewrite = lambda do |definitions|
          definitions.gsub(REFERENCE_DEFINITION_PATTERN) do
            match = ::Regexp.last_match

            "#{match[1]}#{yield(match[2])}#{match[3]}"
          end
        end

        content
          .sub(LEADING_REFERENCE_DEFINITIONS_PATTERN, &rewrite)
          .gsub(FOLLOWING_REFERENCE_DEFINITIONS_PATTERN, &rewrite)
      end

      # Expand relative links that match a pattern, and the links and images in their link text
      #
      # @param content [String] markdown content
      # @param pattern [Regexp] pattern of the links to expand
      # @param base_url [String] base URL for expansion
      # @param source_path [String, nil] path of the file relative to the docs root
      # @return [String] content with expanded links
      def expand_links_matching(content, pattern, base_url, source_path)
        content.gsub(pattern) do
          url = ::Regexp.last_match(2)
          text = expand_links_matching(::Regexp.last_match(1), NESTED_LINK_PATTERN, base_url, source_path)

          "[#{text}](#{expand_target(url, base_url, source_path)})"
        end
      end

      # Expand a link target unless it is absolute, protocol-relative or an anchor
      #
      # @param target [String] link target, optionally followed by a link title
      # @param base_url [String] base URL for expansion
      # @param source_path [String, nil] path of the file relative to the docs root
      # @return [String] expanded or unchanged target
      def expand_target(target, base_url, source_path)
        destination = target.delete_prefix('<')
        return target if destination.start_with?('//', '#') || destination.match?(URI_SCHEME_PATTERN)

        resolve_relative_url(base_url, target, source_path)
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

      # Convert HTML URLs to markdown format
      #
      # Converts absolute URLs anywhere in the content and relative link and link reference definition targets,
      # keeping queries and anchors.
      #
      # @param content [String] markdown content
      # @param convert_definitions [Boolean] whether to convert link reference definition targets
      # @return [String] content with converted URLs
      def convert_html_urls(content, convert_definitions: true)
        result = content.gsub(%r{https?://[^\s<>?#]+?\.html?(?=[?#)\s]|$)}) do |url|
          url.sub(/\.html?\z/, '.md')
        end

        result = result.gsub(/\]\(([^)\s?#]+?)\.html?(?=[?#)\s])/) do |match|
          path = ::Regexp.last_match(1)
          path.match?(URI_SCHEME_PATTERN) ? match : "](#{path}.md"
        end

        return result unless convert_definitions

        rewrite_reference_definitions(result) { |target| convert_html_target(target) }
      end

      # Convert a relative HTML link reference definition target to markdown
      #
      # @param target [String] destination of a definition
      # @return [String] converted or unchanged target
      def convert_html_target(target)
        target.match?(URI_SCHEME_PATTERN) ? target : target.sub(/\A([^?#]+?)\.html?(?=[?#]|\z)/, '\1.md')
      end

      # Simplify verbose link text
      #
      # @param content [String] markdown content
      # @return [String] content with simplified links
      def simplify_links(content)
        content.gsub(LINK_PATTERN) do
          text = ::Regexp.last_match(1)
          url = ::Regexp.last_match(2)

          simplified_text = text
                            .gsub(/^(click here to|see|read more about|check out|visit)\s+(the\s+)?/i, '')
                            .gsub(/\s+(here|documentation|docs)$/i, '')
                            .gsub(/\A\s+|\s+\z/, '') # String#strip also removes the NUL of code placeholders

          simplified_text = text if simplified_text.empty?

          "[#{simplified_text}](#{url})"
        end
      end
    end
  end
end
