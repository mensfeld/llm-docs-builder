# frozen_string_literal: true

require 'pathname'

module LlmsTxt
  module Analyzers
    class Yard < Base
      def analyze
        return {} unless yard_available?

        {
          documentation: extract_yard_docs,
          stats: calculate_documentation_stats,
          examples: extract_code_examples,
          api_summary: generate_api_summary
        }.compact
      end

      private

      def yard_available?
        require 'yard'
        true
      rescue LoadError
        false
      end

      def extract_yard_docs
        return nil unless yard_available?

        YARD::Registry.clear
        YARD.parse(File.join(project_root, 'lib/**/*.rb'))

        docs = {
          classes: [],
          modules: [],
          methods: []
        }

        YARD::Registry.all(:class).each do |obj|
          docs[:classes] << extract_object_info(obj)
        end

        YARD::Registry.all(:module).each do |obj|
          docs[:modules] << extract_object_info(obj)
        end

        YARD::Registry.all(:method).each do |obj|
          docs[:methods] << extract_method_info(obj)
        end

        docs
      rescue StandardError => e
        puts "Error extracting YARD docs: #{e.message}" if LlmsTxt.configuration.verbose
        nil
      end

      def extract_object_info(obj)
        {
          name: obj.name.to_s,
          namespace: obj.namespace.to_s,
          docstring: obj.docstring.to_s,
          tags: extract_tags(obj),
          visibility: obj.visibility,
          file: relative_path(obj.file),
          line: obj.line
        }.compact
      end

      def extract_method_info(obj)
        info = extract_object_info(obj)
        info.merge!(
          parameters: extract_parameters(obj),
          return_type: extract_return_type(obj),
          raises: extract_raises(obj),
          examples: extract_examples(obj)
        ).compact
      end

      def extract_tags(obj)
        return nil unless obj.tags && !obj.tags.empty?

        obj.tags.map do |tag|
          result = {
            tag_name: tag.tag_name,
            name: tag.name,
            text: tag.text
          }
          result[:types] = tag.types if tag.respond_to?(:types)
          result.compact
        end
      end

      def extract_parameters(method_obj)
        return nil if method_obj.parameters.empty?

        method_obj.parameters.map do |param|
          param_tag = method_obj.tags(:param).find { |t| t.name == param[0].to_s }

          {
            name: param[0].to_s,
            default: param[1],
            description: param_tag&.text,
            types: param_tag&.types
          }.compact
        end
      end

      def extract_return_type(method_obj)
        return_tags = method_obj.tags(:return)
        return nil if return_tags.empty?

        {
          types: return_tags.first.types,
          description: return_tags.first.text
        }
      end

      def extract_raises(method_obj)
        raise_tags = method_obj.tags(:raise)
        return nil if raise_tags.empty?

        raise_tags.map do |tag|
          {
            types: tag.types,
            description: tag.text
          }
        end
      end

      def extract_examples(obj)
        example_tags = obj.tags(:example)
        return nil if example_tags.empty?

        example_tags.map do |tag|
          {
            name: tag.name,
            code: tag.text
          }
        end
      end

      def extract_code_examples
        examples = []

        YARD::Registry.all.each do |obj|
          next unless obj.tags(:example).any?

          obj.tags(:example).each do |example|
            examples << {
              object: "#{obj.namespace}#{obj.type == :class ? '.' : '#'}#{obj.name}",
              title: example.name,
              code: example.text
            }
          end
        end

        examples.empty? ? nil : examples
      end

      def generate_api_summary
        return nil unless YARD::Registry.all.any?

        {
          total_objects: YARD::Registry.all.size,
          classes: YARD::Registry.all(:class).size,
          modules: YARD::Registry.all(:module).size,
          methods: YARD::Registry.all(:method).size,
          documented_percent: calculate_documented_percent,
          public_api_count: count_public_api
        }
      end

      def calculate_documentation_stats
        return nil unless yard_available?

        stats = {
          documented: 0,
          undocumented: 0,
          total: 0
        }

        YARD::Registry.all.each do |obj|
          stats[:total] += 1
          if obj.docstring.empty?
            stats[:undocumented] += 1
          else
            stats[:documented] += 1
          end
        end

        stats[:percentage] = (stats[:documented].to_f / stats[:total] * 100).round(2) if stats[:total].positive?
        stats
      end

      def calculate_documented_percent
        total = YARD::Registry.all.size
        return 0 if total.zero?

        documented = YARD::Registry.all.count { |obj| !obj.docstring.empty? }
        (documented.to_f / total * 100).round(2)
      end

      def count_public_api
        YARD::Registry.all.count { |obj| obj.visibility == :public }
      end

      def relative_path(file_path)
        return nil unless file_path

        Pathname.new(file_path).relative_path_from(Pathname.new(project_root)).to_s
      rescue StandardError
        file_path
      end
    end
  end
end
