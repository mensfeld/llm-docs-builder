# frozen_string_literal: true

RSpec.describe LlmDocsBuilder::MarkdownFinder do
  let(:temp_dir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe '#files' do
    before do
      FileUtils.mkdir_p(File.join(temp_dir, 'private', 'sub'))
      FileUtils.mkdir_p(File.join(temp_dir, '.github'))
      File.write(File.join(temp_dir, 'README.md'), "# Readme\n")
      File.write(File.join(temp_dir, 'private', 'a.md'), "# A\n")
      File.write(File.join(temp_dir, 'private', 'sub', 'b.md'), "# B\n")
      File.write(File.join(temp_dir, '.github', 'c.md'), "# C\n")
    end

    def relative_files(finder)
      finder.files.map { |path| path.delete_prefix("#{temp_dir}/") }
    end

    it 'skips hidden directories by default' do
      finder = described_class.new(temp_dir)

      expect(relative_files(finder)).to contain_exactly('README.md', 'private/a.md', 'private/sub/b.md')
    end

    it 'includes hidden directories when include_hidden is true' do
      finder = described_class.new(temp_dir, include_hidden: true)

      expect(relative_files(finder)).to include('.github/c.md')
    end

    it 'does not skip the docs_path itself when it is .' do
      FileUtils.mkdir_p(File.join(temp_dir, 'guide'))
      File.write(File.join(temp_dir, 'guide', 'a.md'), "# A\n")

      files = Dir.chdir(temp_dir) { described_class.new('.').files }

      expect(files).to contain_exactly('./README.md', './guide/a.md', './private/a.md', './private/sub/b.md')
    end

    it 'skips files nested below an excluded directory' do
      finder = described_class.new(temp_dir, excludes: ['**/private/**'])

      expect(relative_files(finder)).to eq(['README.md'])
    end
  end

  describe '#excluded?' do
    it 'returns false when no excludes are specified' do
      finder = described_class.new(temp_dir)
      expect(finder.excluded?('README.md')).to be false
    end

    it 'returns false when excludes is empty array' do
      finder = described_class.new(temp_dir, excludes: [])
      expect(finder.excluded?('README.md')).to be false
    end

    it 'excludes files matching simple pattern' do
      finder = described_class.new(temp_dir, excludes: ['draft.md'])
      expect(finder.excluded?(File.join(temp_dir, 'draft.md'))).to be true
    end

    it 'excludes files matching glob pattern' do
      finder = described_class.new(temp_dir, excludes: ['**/private/**'])
      expect(finder.excluded?(File.join(temp_dir, 'private', 'secret.md'))).to be true
    end

    it 'excludes files nested below a trailing /** pattern' do
      finder = described_class.new(temp_dir, excludes: ['**/private/**'])
      expect(finder.excluded?(File.join(temp_dir, 'private', 'sub', 'b.md'))).to be true
    end

    it 'excludes files matching wildcard pattern' do
      finder = described_class.new(temp_dir, excludes: ['draft-*.md'])
      expect(finder.excluded?(File.join(temp_dir, 'draft-proposal.md'))).to be true
    end

    it 'does not exclude files that do not match pattern' do
      finder = described_class.new(temp_dir, excludes: ['draft.md'])
      expect(finder.excluded?(File.join(temp_dir, 'README.md'))).to be false
    end

    it 'handles multiple exclude patterns' do
      finder = described_class.new(temp_dir, excludes: ['draft.md', 'private/**', '*.tmp.md'])
      expect(finder.excluded?(File.join(temp_dir, 'draft.md'))).to be true
      expect(finder.excluded?(File.join(temp_dir, 'private/secret.md'))).to be true
      expect(finder.excluded?(File.join(temp_dir, 'test.tmp.md'))).to be true
      expect(finder.excluded?(File.join(temp_dir, 'README.md'))).to be false
    end
  end
end
