# frozen_string_literal: true

module LlmDocsBuilder
  # Advanced text compression techniques for reducing token count
  #
  # Provides more aggressive text compression methods including stopword removal,
  # duplicate content detection, and sentence deduplication. These methods are more
  # aggressive than basic markdown cleanup and should be used carefully.
  #
  # @example Basic usage
  #   compressor = LlmDocsBuilder::TextCompressor.new
  #   compressed = compressor.compress("Your text here", remove_stopwords: true)
  #
  # @api public
  class TextCompressor
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
    def compress(content, methods = {})
      result = content.dup

      result = remove_stopwords(result) if methods[:remove_stopwords]
      result = remove_duplicate_paragraphs(result) if methods[:remove_duplicates]

      result
    end

    # Remove stopwords from text while preserving technical content
    #
    # Removes common English stopwords that don't carry significant meaning.
    # Preserves code blocks, inline code, and technical terms.
    #
    # @deprecated This is an aggressive optimization that may affect readability.
    #   Use with caution and test results carefully.
    #
    # @param content [String] text to process
    # @return [String] text with stopwords removed
    def remove_stopwords(content)
      # Preserve code blocks by temporarily replacing them
      code_blocks = {}
      code_counter = 0

      # Extract and preserve fenced code blocks
      content = content.gsub(/^```.*?^```/m) do |match|
        placeholder = "___CODE_BLOCK_#{code_counter}___"
        code_blocks[placeholder] = match
        code_counter += 1
        placeholder
      end

      # Extract and preserve inline code
      content = content.gsub(/`[^`]+`/) do |match|
        placeholder = "___INLINE_CODE_#{code_counter}___"
        code_blocks[placeholder] = match
        code_counter += 1
        placeholder
      end

      # Get combined stopwords list
      stopwords_list = STOPWORDS + options[:custom_stopwords]

      # Process each line
      content = content.split("\n").map do |line|
        # Skip markdown headers, lists, and links
        if line.match?(/^#+\s/) || line.match?(/^[\*\-]\s/) || line.match?(/\[[^\]]+\]\([^)]+\)/)
          line
        else
          # Remove stopwords from regular text
          words = line.split(/\b/)
          words.map do |word|
            # Preserve the word if it's not a stopword or if we should preserve technical terms
            if stopwords_list.include?(word.downcase) && !word.match?(/^[A-Z]/) # Don't remove capitalized words
              ''
            else
              word
            end
          end.join
        end
      end.join("\n")

      # Restore code blocks
      code_blocks.each do |placeholder, original|
        content = content.gsub(placeholder, original)
      end

      content
    end

    # Remove duplicate paragraphs from text
    #
    # Detects and removes paragraphs that are duplicates or near-duplicates.
    # Documentation often repeats concepts across different sections.
    #
    # @param content [String] text to process
    # @return [String] text with duplicate paragraphs removed
    def remove_duplicate_paragraphs(content)
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

        # Check if we've seen this or similar paragraph
        unless seen[normalized]
          seen[normalized] = true
          unique_paragraphs << para
        end
      end

      unique_paragraphs.join("\n\n")
    end

  end
end
