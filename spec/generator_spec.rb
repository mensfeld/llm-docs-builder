# frozen_string_literal: true

require 'llm_docs_builder/generator'
require 'tempfile'
require 'fileutils'

RSpec.describe LlmDocsBuilder::Generator do
  let(:temp_dir) { Dir.mktmpdir }
  let(:generator) { described_class.new(temp_dir) }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe '#initialize' do
    it 'sets docs_path and options' do
      gen = described_class.new('/path/to/docs', title: 'Test')
      expect(gen.docs_path).to eq('/path/to/docs')
      expect(gen.options).to eq({ title: 'Test' })
    end
  end

  describe '#generate' do
    it 'generates llms.txt content from directory' do
      File.write(File.join(temp_dir, 'README.md'), "# Test Project\n\nA test project")
      File.write(File.join(temp_dir, 'guide.md'), "# Guide\n\nA helpful guide")

      gen = described_class.new(temp_dir)
      content = gen.generate

      expect(content).to include('# Test Project')
      expect(content).to include('## Documentation')
      expect(content).to include('[Test Project](README.md)')
      expect(content).to include('[Guide](guide.md)')
    end

    it 'generates llms.txt with base_url' do
      File.write(File.join(temp_dir, 'guide.md'), "# Guide\n\nA guide")

      gen = described_class.new(temp_dir, base_url: 'https://example.com')
      content = gen.generate

      expect(content).to include('https://example.com/guide.md')
    end

    it 'writes to output file when specified' do
      File.write(File.join(temp_dir, 'README.md'), "# Project\n\nDescription")
      output_path = File.join(temp_dir, 'llms.txt')

      gen = described_class.new(temp_dir, output: output_path)
      content = gen.generate

      expect(File.exist?(output_path)).to be true
      expect(File.read(output_path)).to eq(content)
    end

    it 'uses custom title and description when provided' do
      File.write(File.join(temp_dir, 'guide.md'), "# Guide\n\nA guide")

      gen = described_class.new(temp_dir, title: 'Custom Title', description: 'Custom description')
      content = gen.generate

      expect(content).to include('# Custom Title')
      expect(content).to include('> Custom description')
    end

    it 'handles single file path' do
      file_path = File.join(temp_dir, 'single.md')
      File.write(file_path, "# Single File\n\nContent here")

      gen = described_class.new(file_path)
      content = gen.generate

      expect(content).to include('[Single File](single.md)')
    end

    it 'handles non-existent path' do
      gen = described_class.new('/nonexistent/path')
      content = gen.generate

      expect(content).to include('# llm-docs-builder')
      expect(content.lines.count).to be < 10 # No files listed
    end
  end

  describe 'private methods' do

    describe '#extract_title' do
      it 'extracts title from H1 header' do
        content = "# My Title\n\nSome content"
        file_path = File.join(temp_dir, 'file.md')

        title = generator.send(:extract_title, content, file_path)
        expect(title).to eq('My Title')
      end

      it 'strips whitespace from extracted title' do
        content = "#   Title With Spaces   \n\nContent"
        file_path = File.join(temp_dir, 'file.md')

        title = generator.send(:extract_title, content, file_path)
        expect(title).to eq('Title With Spaces')
      end

      it 'generates title from filename when no H1 header' do
        content = "Some content without a header\n"
        file_path = File.join(temp_dir, 'my-awesome_file.md')

        title = generator.send(:extract_title, content, file_path)
        expect(title).to eq('My Awesome File')
      end
    end

    describe '#extract_description' do
      it 'extracts first paragraph after title' do
        content = "# Title\n\nThis is the description.\nIt continues here.\n\nSecond paragraph"

        description = generator.send(:extract_description, content)
        expect(description).to include('This is the description')
        expect(description).to include('It continues here')
      end

      it 'skips empty lines before description' do
        content = "# Title\n\n\n\nDescription here"

        description = generator.send(:extract_description, content)
        expect(description).to eq('Description here')
      end

      it 'truncates description to 200 characters' do
        long_text = 'a' * 300
        content = "# Title\n\n#{long_text}"

        description = generator.send(:extract_description, content)
        expect(description.length).to eq(200)
      end

      it 'returns empty string when no description' do
        content = "# Title\n\n"

        description = generator.send(:extract_description, content)
        expect(description).to eq('')
      end
    end

    describe '#calculate_priority' do
      it 'returns 1 for README files' do
        priority = generator.send(:calculate_priority, 'README.md')
        expect(priority).to eq(1)
      end

      it 'returns 1 for readme files (lowercase)' do
        priority = generator.send(:calculate_priority, 'readme.md')
        expect(priority).to eq(1)
      end

      it 'returns 2 for getting started files' do
        priority = generator.send(:calculate_priority, 'getting-started.md')
        expect(priority).to eq(2)
      end

      it 'returns 3 for guide files' do
        priority = generator.send(:calculate_priority, 'user-guide.md')
        expect(priority).to eq(3)
      end

      it 'returns 4 for tutorial files' do
        priority = generator.send(:calculate_priority, 'tutorial.md')
        expect(priority).to eq(4)
      end

      it 'returns 5 for API files' do
        priority = generator.send(:calculate_priority, 'api.md')
        expect(priority).to eq(5)
      end

      it 'returns 6 for reference files' do
        file_path = File.join(temp_dir, 'command-reference.md')
        priority = generator.send(:calculate_priority, file_path)
        expect(priority).to eq(6)
      end

      it 'returns 7 for files with no special pattern' do
        file_path = File.join(temp_dir, 'random-file.md')
        priority = generator.send(:calculate_priority, file_path)
        expect(priority).to eq(7)
      end
    end

    describe '#detect_project_title' do
      it 'returns README title when README exists' do
        docs = [
          { path: 'README.md', title: 'My Project' },
          { path: 'guide.md', title: 'Guide' }
        ]

        title = generator.send(:detect_project_title, docs)
        expect(title).to eq('My Project')
      end

      it 'returns directory name when no README' do
        docs = [{ path: 'guide.md', title: 'Guide' }]

        title = generator.send(:detect_project_title, docs)
        expect(title).to be_a(String)
        expect(title).not_to be_empty
      end

      it 'finds README with case insensitive match' do
        docs = [
          { path: 'readme.md', title: 'Project Title' },
          { path: 'guide.md', title: 'Guide' }
        ]

        title = generator.send(:detect_project_title, docs)
        expect(title).to eq('Project Title')
      end
    end

    describe '#detect_project_description' do
      it 'returns description when readme has one' do
        docs = [{ path: 'readme.md', description: 'A great project' }]
        description = generator.send(:detect_project_description, docs)
        expect(description).to eq('A great project')
      end

      it 'returns nil when readme has no description' do
        docs = [{ path: 'readme.md', description: nil }]
        description = generator.send(:detect_project_description, docs)
        expect(description).to be_nil
      end

      it 'returns empty string when readme has empty description' do
        docs = [{ path: 'readme.md', description: '' }]
        description = generator.send(:detect_project_description, docs)
        expect(description).to eq('')
      end

      it 'returns nil when no readme found' do
        docs = [{ path: 'guide.md', description: 'A guide' }]
        description = generator.send(:detect_project_description, docs)
        expect(description).to be_nil
      end
    end

    describe '#build_url' do
      it 'returns path when base_url not provided' do
        generator_without_url = described_class.new(temp_dir)
        url = generator_without_url.send(:build_url, 'docs/guide.md')
        expect(url).to eq('docs/guide.md')
      end

      it 'joins base_url with path when provided' do
        generator_with_url = described_class.new(temp_dir, base_url: 'https://example.com')
        url = generator_with_url.send(:build_url, 'docs/guide.md')
        expect(url).to eq('https://example.com/docs/guide.md')
      end
    end

    describe '#build_llms_txt' do
      it 'builds content with title and documentation section' do
        docs = [
          { path: 'guide.md', title: 'Guide', description: 'A guide', priority: 3 }
        ]

        content = generator.send(:build_llms_txt, docs)

        expect(content).to include('## Documentation')
        expect(content).to include('[Guide](guide.md)')
        expect(content).to include('A guide')
      end

      it 'includes description when provided' do
        gen = described_class.new(temp_dir, description: 'Project description')
        docs = []

        content = gen.send(:build_llms_txt, docs)

        expect(content).to include('> Project description')
      end

      it 'omits description line when not provided' do
        docs = []

        content = generator.send(:build_llms_txt, docs)

        expect(content).not_to include('>')
      end

      it 'handles docs without descriptions' do
        docs = [
          { path: 'guide.md', title: 'Guide', description: '', priority: 3 }
        ]

        content = generator.send(:build_llms_txt, docs)

        expect(content).to include('[Guide](guide.md)')
        expect(content).not_to match(/\[Guide\].*:/)
      end

      it 'handles empty docs array' do
        docs = []

        content = generator.send(:build_llms_txt, docs)

        expect(content).to include('# llm-docs-builder')
        expect(content.lines.count).to be < 10
      end
    end

    describe '#find_markdown_files_in_directory' do
      it 'finds markdown files recursively' do
        subdir = File.join(temp_dir, 'subdir')
        FileUtils.mkdir_p(subdir)
        File.write(File.join(temp_dir, 'file1.md'), "# File 1\n\nContent")
        File.write(File.join(subdir, 'file2.md'), "# File 2\n\nContent")

        files = generator.send(:find_markdown_files_in_directory)

        expect(files.length).to eq(2)
        expect(files.map { |f| f[:title] }).to include('File 1', 'File 2')
      end

      it 'skips hidden files' do
        File.write(File.join(temp_dir, 'visible.md'), "# Visible\n\nContent")
        File.write(File.join(temp_dir, '.hidden.md'), "# Hidden\n\nContent")

        files = generator.send(:find_markdown_files_in_directory)

        expect(files.length).to eq(1)
        expect(files.first[:title]).to eq('Visible')
      end

      it 'sorts files by priority' do
        File.write(File.join(temp_dir, 'guide.md'), "# Guide\n")
        File.write(File.join(temp_dir, 'README.md'), "# Readme\n")
        File.write(File.join(temp_dir, 'other.md'), "# Other\n")

        files = generator.send(:find_markdown_files_in_directory)

        expect(files.first[:path]).to eq('README.md')
        expect(files.last[:priority]).to eq(7)
      end
    end

    describe '#analyze_file' do
      it 'extracts metadata from file' do
        file_path = File.join(temp_dir, 'test.md')
        File.write(file_path, "# Test Title\n\nTest description")

        metadata = generator.send(:analyze_file, file_path)

        expect(metadata[:path]).to eq('test.md')
        expect(metadata[:title]).to eq('Test Title')
        expect(metadata[:description]).to include('Test description')
        expect(metadata[:priority]).to eq(7)
      end

      it 'handles single file with correct relative path' do
        file_path = File.join(temp_dir, 'single.md')
        File.write(file_path, "# Single\n\nContent")
        gen = described_class.new(file_path)

        metadata = gen.send(:analyze_file, file_path)

        expect(metadata[:path]).to eq('single.md')
      end
    end
  end
end
