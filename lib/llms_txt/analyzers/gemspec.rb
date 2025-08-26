# frozen_string_literal: true

module LlmsTxt
  module Analyzers
    class Gemspec < Base
      def analyze
        gemspec_file = find_gemspec
        return {} unless gemspec_file

        spec = load_gemspec(gemspec_file)
        return {} unless spec

        {
          name: spec.name,
          version: spec.version.to_s,
          summary: spec.summary,
          description: spec.description,
          authors: spec.authors,
          email: spec.email,
          homepage: spec.homepage,
          license: spec.license || spec.licenses&.first,
          metadata: extract_metadata(spec),
          dependencies: extract_dependencies(spec),
          files: extract_file_info(spec),
          executables: spec.executables,
          required_ruby_version: spec.required_ruby_version&.to_s
        }.compact
      end

      private

      def find_gemspec
        gemspecs = find_files('*.gemspec')
        gemspecs.first&.gsub("#{project_root}/", '')
      end

      def load_gemspec(gemspec_file)
        path = File.join(project_root, gemspec_file)

        spec_content = File.read(path)

        eval(spec_content, binding, path)
      rescue StandardError => e
        puts "Error loading gemspec: #{e.message}" if LlmsTxt.configuration.verbose
        nil
      end

      def extract_metadata(spec)
        return {} unless spec.metadata

        {
          documentation_uri: spec.metadata['documentation_uri'],
          changelog_uri: spec.metadata['changelog_uri'],
          source_code_uri: spec.metadata['source_code_uri'],
          bug_tracker_uri: spec.metadata['bug_tracker_uri'],
          wiki_uri: spec.metadata['wiki_uri'],
          mailing_list_uri: spec.metadata['mailing_list_uri'],
          rubygems_mfa_required: spec.metadata['rubygems_mfa_required']
        }.compact
      end

      def extract_dependencies(spec)
        {
          runtime: spec.runtime_dependencies.map { |d| dependency_info(d) },
          development: spec.development_dependencies.map { |d| dependency_info(d) }
        }
      end

      def dependency_info(dep)
        {
          name: dep.name,
          requirement: dep.requirement.to_s
        }
      end

      def extract_file_info(spec)
        {
          count: spec.files&.size,
          test_files: spec.test_files&.size,
          has_extensions: !spec.extensions.empty?,
          extensions: spec.extensions
        }.compact
      end
    end
  end
end
