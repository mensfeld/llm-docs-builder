# frozen_string_literal: true

module LlmDocsBuilder
  # Advanced text compression techniques for reducing token count
  #
  # Provides more aggressive text compression methods including stopword removal, duplicate content detection, and
  # sentence deduplication. These methods are more aggressive than basic markdown cleanup and should be used carefully.
  #
  # @example Basic usage
  #   compressor = LlmDocsBuilder::TextCompressor.new
  #   compressed = compressor.compress("Your text here", remove_stopwords: true)
  #
  # @api public
  class TextCompressor
    include Transformers::CodeBlocks

    # Common English stopwords that can be safely removed from documentation
    # Excludes words that might be important in technical contexts (like "not", "no")
    STOPWORDS = %w[
      a an the this that these those
      is am are was were be being been
      have has had do does did
      will would shall should may might must can could
      i me my mine we us our ours
      you your yours
      he him his she her hers it its
      they them their theirs
      what which who whom whose where when why how
      all both each few more most other some such
      and or but if then else
      at by for from in into of on to with
      as so than
      very really quite
      there here
      about above across after against along among around because before behind below
      beneath beside besides between beyond during except inside near off since through
      throughout under until up upon within without
    ].freeze

    # Word, or a code placeholder or bare URL that stopword removal leaves unchanged
    WORD_PATTERN = %r{#{CODE_PLACEHOLDER}|https?://\S+|[[:word:]]+}

    private_constant :WORD_PATTERN

    # @return [Hash] compression options
    attr_reader :options

    # Initialize a new text compressor
    #
    # @param options [Hash] compression options
    # @option options [Array<String>] :custom_stopwords additional stopwords to remove
    # @option options [Boolean] :preserve_technical preserve technical terms and code
    def initialize(options = {})
      @options = {
        preserve_technical: true,
        custom_stopwords: []
      }.merge(options)
    end

    # Compress text using configured methods
    #
    # @param content [String] text to compress
    # @param methods [Hash] compression methods to apply
    # @option methods [Boolean] :remove_stopwords remove common filler words
    # @option methods [Boolean] :remove_duplicates remove duplicate sentences/paragraphs
    # @return [String] compressed text
    # @note Code (fenced and indented code blocks, inline code spans) is left unchanged
    def compress(content, methods = {})
      return content.dup unless methods[:remove_stopwords] || methods[:remove_duplicates]

      outside_code(content) { |text| compress_outside_code(text, methods) }
    end

    # Compress text whose code is already replaced by placeholders
    #
    # @param text [String] text with code replaced by {Transformers::CodeBlocks} placeholders
    # @param methods [Hash] compression methods to apply
    # @option methods [Boolean] :remove_stopwords remove common filler words
    # @option methods [Boolean] :remove_duplicates remove duplicate sentences/paragraphs
    # @return [String] compressed text, still with placeholders
    # @api private
    def compress_outside_code(text, methods = {})
      text = remove_stopwords_outside_code(text) if methods[:remove_stopwords]
      text = remove_duplicate_paragraphs_outside_code(text) if methods[:remove_duplicates]
      text
    end

    # Remove stopwords from text while preserving technical content
    #
    # Removes common English stopwords that don't carry significant meaning.
    # Preserves code blocks, inline code, bare URLs and technical terms.
    #
    # @deprecated This is an aggressive optimization that may affect readability.
    #   Use with caution and test results carefully.
    #
    # @param content [String] text to process
    # @return [String] text with stopwords removed
    def remove_stopwords(content)
      outside_code(content) { |text| remove_stopwords_outside_code(text) }
    end

    # Remove duplicate paragraphs from text
    #
    # Detects and removes paragraphs that are the same after whitespace and case normalization.
    # Documentation often repeats concepts across different sections. Paragraphs with code are always kept.
    #
    # @param content [String] text to process
    # @return [String] text with duplicate paragraphs removed
    def remove_duplicate_paragraphs(content)
      outside_code(content) { |text| remove_duplicate_paragraphs_outside_code(text) }
    end

    private

    # Remove stopwords from text whose code is replaced by placeholders
    #
    # @param content [String] text with code replaced by {Transformers::CodeBlocks} placeholders
    # @return [String] text with stopwords removed
    def remove_stopwords_outside_code(content)
      # Get combined stopwords list
      stopwords_list = STOPWORDS + options[:custom_stopwords]

      # Process each line
      content.split("\n").map do |line|
        # Skip markdown headers, lists, and links
        if line.match?(/^#+\s/) || line.match?(/^[\*\-]\s/) || line.match?(/\[[^\]]+\]\([^)]+\)/)
          line
        else
          # Remove stopwords from regular text
          line.gsub(WORD_PATTERN) do |word|
            # Preserve the word if it's not a stopword or if we should preserve technical terms
            if stopwords_list.include?(word.downcase) && !word.match?(/^[A-Z]/) # Don't remove capitalized words
              ''
            else
              word
            end
          end
        end
      end.join("\n")
    end

    # Remove duplicate paragraphs from text whose code is replaced by placeholders
    #
    # @param content [String] text with code replaced by {Transformers::CodeBlocks} placeholders
    # @return [String] text with duplicate paragraphs removed
    def remove_duplicate_paragraphs_outside_code(content)
      # Split into paragraphs (separated by blank lines)
      paragraphs = content.split(/\n\s*\n/)

      # Track seen paragraphs with normalized comparison
      seen = {}
      unique_paragraphs = []

      paragraphs.each do |para|
        # Normalize for comparison (remove extra whitespace, lowercase)
        normalized = para.gsub(/\s+/, ' ').strip.downcase

        # Skip empty paragraphs
        next if normalized.empty?

        # Code placeholders are unique, so a paragraph with code is never a duplicate
        unless seen[normalized]
          seen[normalized] = true
          unique_paragraphs << para
        end
      end

      unique_paragraphs.join("\n\n")
    end
  end
end
