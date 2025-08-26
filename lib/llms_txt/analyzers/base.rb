# frozen_string_literal: true

module LlmsTxt
  module Analyzers
    class Base
      attr_reader :project_root

      def initialize(project_root)
        @project_root = project_root
      end

      def analyze
        raise NotImplementedError, "#{self.class} must implement #analyze"
      end

      protected

      def file_exists?(relative_path)
        File.exist?(File.join(project_root, relative_path))
      end

      def read_file(relative_path)
        path = File.join(project_root, relative_path)
        return nil unless File.exist?(path)

        File.read(path)
      end

      def find_files(pattern)
        Dir.glob(File.join(project_root, pattern))
      end

      def extract_markdown_sections(content)
        sections = {}
        current_section = nil
        current_content = []

        content.lines.each do |line|
          if line =~ /^##?\s+(.+)$/
            save_section(sections, current_section, current_content)
            current_section = Regexp.last_match(1).downcase.gsub(/\s+/, '_').to_sym
            current_content = []
          else
            current_content << line
          end
        end

        save_section(sections, current_section, current_content)
        sections
      end

      private

      def save_section(sections, name, content)
        return if name.nil? || content.empty?

        sections[name] = content.join.strip
      end
    end
  end
end
