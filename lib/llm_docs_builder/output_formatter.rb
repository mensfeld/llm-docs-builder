# frozen_string_literal: true

module LlmDocsBuilder
  # Formats output for CLI display
  #
  # Provides formatting utilities for displaying comparison results,
  # byte sizes, and numbers in a user-friendly way.
  #
  # @api private
  class OutputFormatter
    # Format bytes into human-readable string
    #
    # @param bytes [Integer] number of bytes
    # @return [String] formatted string with units (bytes/KB/MB)
    #
    # @example
    #   OutputFormatter.format_bytes(1024)      #=> "1.0 KB"
    #   OutputFormatter.format_bytes(1048576)   #=> "1.0 MB"
    def self.format_bytes(bytes)
      if bytes < 1024
        "#{bytes} bytes"
      elsif bytes < 1024 * 1024
        "#{(bytes / 1024.0).round(1)} KB"
      else
        "#{(bytes / (1024.0 * 1024)).round(2)} MB"
      end
    end

    # Format number with comma separators for readability
    #
    # @param number [Integer] number to format
    # @return [String] formatted number with commas
    #
    # @example
    #   OutputFormatter.format_number(1234567)  #=> "1,234,567"
    def self.format_number(number)
      number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end

    # Display formatted comparison results
    #
    # @param result [Hash] comparison results from Comparator
    def self.display_comparison_results(result)
      puts ''
      puts '=' * 60
      puts 'Context Window Comparison'
      puts '=' * 60
      puts ''
      puts "Human version:  #{format_bytes(result[:human_size])} (~#{format_number(result[:human_tokens])} tokens)"
      puts "  Source: #{result[:human_source]}"
      puts ''
      puts "AI version:     #{format_bytes(result[:ai_size])} (~#{format_number(result[:ai_tokens])} tokens)"
      puts "  Source: #{result[:ai_source]}"
      puts ''
      puts '-' * 60

      if result[:reduction_bytes].positive?
        display_reduction(result)
      elsif result[:reduction_bytes].negative?
        display_increase(result)
      else
        puts 'Same size'
      end

      puts '=' * 60
      puts ''
    end

    # Display reduction statistics
    #
    # @param result [Hash] comparison results
    # @api private
    def self.display_reduction(result)
      puts "Reduction:      #{format_bytes(result[:reduction_bytes])} (#{result[:reduction_percent]}%)"
      puts "Token savings:  #{format_number(result[:token_reduction])} tokens (#{result[:token_reduction_percent]}%)"
      puts "Factor:         #{result[:factor]}x smaller"
    end

    # Display increase statistics
    #
    # @param result [Hash] comparison results
    # @api private
    def self.display_increase(result)
      increase_bytes = result[:reduction_bytes].abs
      increase_percent = result[:reduction_percent].abs
      token_increase = result[:token_reduction].abs
      token_increase_percent = result[:token_reduction_percent].abs
      puts "Increase:       #{format_bytes(increase_bytes)} (#{increase_percent}%)"
      puts "Token increase: #{format_number(token_increase)} tokens (#{token_increase_percent}%)"
      puts "Factor:         #{result[:factor]}x larger"
    end
  end
end
