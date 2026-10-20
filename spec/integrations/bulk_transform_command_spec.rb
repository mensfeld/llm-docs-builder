# frozen_string_literal: true

RSpec.describe 'bulk-transform command' do
  let(:cli_path) { File.expand_path('../../bin/llm-docs-builder', __dir__) }
  let(:temp_dir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  def run_cli(*args)
    cmd = "bundle exec #{cli_path} #{args.join(' ')}"
    stdout, stderr, status = Open3.capture3(cmd)
    [stdout, stderr, status]
  end

  it 'transforms all markdown files in directory recursively' do
    # Create directory structure with multiple markdown files
    docs_dir = File.join(temp_dir, 'docs')
    FileUtils.mkdir_p(File.join(docs_dir, 'api'))

    File.write(File.join(docs_dir, 'README.md'), "# README\n\nContent here")
    File.write(File.join(docs_dir, 'guide.md'), "# Guide\n\nGuide content")
    File.write(File.join(docs_dir, 'api', 'reference.md'), "# API\n\nAPI docs")

    # Run bulk-transform
    stdout, _stderr, status = run_cli('bulk-transform', '--docs', docs_dir)

    # Verify success
    expect(status.success?).to be true
    expect(stdout).to include('Successfully transformed')
    expect(stdout).to include('3 files')

    # Verify transformed files exist with default .llm.md suffix
    expect(File.exist?(File.join(docs_dir, 'README.llm.md'))).to be true
    expect(File.exist?(File.join(docs_dir, 'guide.llm.md'))).to be true
    expect(File.exist?(File.join(docs_dir, 'api', 'reference.llm.md'))).to be true
  end

  it 'works with custom suffix from config file' do
    # Create docs
    docs_dir = File.join(temp_dir, 'docs')
    FileUtils.mkdir_p(docs_dir)
    File.write(File.join(docs_dir, 'README.md'), "# README\n\nContent")

    # Create config with custom suffix
    config_file = File.join(temp_dir, 'config.yml')
    File.write(config_file, <<~YAML)
      docs: #{docs_dir}
      suffix: .ai
      base_url: https://example.com
    YAML

    # Run bulk-transform with config
    _, _stderr, status = run_cli('bulk-transform', '--config', config_file)

    # Verify custom suffix was used
    expect(status.success?).to be true
    expect(File.exist?(File.join(docs_dir, 'README.ai.md'))).to be true
  end

  it 'skips already transformed files on repeated runs and in generate' do
    docs_dir = File.join(temp_dir, 'docs')
    FileUtils.mkdir_p(File.join(docs_dir, 'api'))

    File.write(File.join(docs_dir, 'README.md'), "# README\n\nContent here")
    File.write(File.join(docs_dir, 'guide.md'), "# Guide\n\nGuide content")
    File.write(File.join(docs_dir, 'api', 'reference.md'), "# API\n\nAPI docs")

    config_file = File.join(temp_dir, 'config.yml')
    output_file = File.join(temp_dir, 'llms.txt')
    File.write(config_file, <<~YAML)
      docs: #{docs_dir}
      output: #{output_file}
      base_url: https://example.com/docs/
    YAML

    2.times do
      stdout, _stderr, status = run_cli('bulk-transform', '--config', config_file)

      expect(status.success?).to be true
      expect(stdout).to include('3 files')
    end

    files = Dir.glob(File.join(docs_dir, '**', '*.md')).map { |f| f.delete_prefix("#{docs_dir}/") }
    expect(files).to contain_exactly(
      'README.md', 'README.llm.md',
      'guide.md', 'guide.llm.md',
      'api/reference.md', 'api/reference.llm.md'
    )

    _, _stderr, status = run_cli('generate', '--config', config_file)

    expect(status.success?).to be true

    links = File.read(output_file).lines.grep(/\A- \[/)
    expect(links).to contain_exactly(
      "- [README](https://example.com/docs/README.md): Content here\n",
      "- [Guide](https://example.com/docs/guide.md): Guide content\n",
      "- [API](https://example.com/docs/api/reference.md): API docs\n"
    )
  end

  it 'resolves angle-bracket link destinations with spaces' do
    docs_dir = File.join(temp_dir, 'docs')
    FileUtils.mkdir_p(File.join(docs_dir, 'guides', 'sub'))
    FileUtils.mkdir_p(File.join(docs_dir, 'my docs'))

    File.write(File.join(docs_dir, 'my docs', 'a b.md'), "# Target\n\nTarget content")
    File.write(File.join(docs_dir, 'guides', 'sub', 'page.md'), <<~MD)
      # Page

      See [spa](<../../my docs/a b.md>) and [abs](<https://other.io/x y.md>).
    MD

    config_file = File.join(temp_dir, 'config.yml')
    File.write(config_file, <<~YAML)
      docs: #{docs_dir}
      base_url: https://myproject.io/docs/
    YAML

    _, _stderr, status = run_cli('bulk-transform', '--config', config_file)

    expect(status.success?).to be true

    content = File.read(File.join(docs_dir, 'guides', 'sub', 'page.llm.md'))
    expect(content).to include(
      'See [spa](https://myproject.io/docs/my%20docs/a%20b.md) and [abs](<https://other.io/x y.md>).'
    )
  end

  it 'resolves query-only links to the current page' do
    docs_dir = File.join(temp_dir, 'docs')
    FileUtils.mkdir_p(File.join(docs_dir, 'guides', 'sub'))

    File.write(File.join(docs_dir, 'guides', 'sub', 'page.md'), <<~MD)
      # Page

      See [q](?tab=2), [qa](<?tab=3#part>) and [self](#self).
    MD
    File.write(File.join(docs_dir, 'guides', 'my page.md'), <<~MD)
      # My Page

      See [q](?tab=2).
    MD

    config_file = File.join(temp_dir, 'config.yml')
    File.write(config_file, <<~YAML)
      docs: #{docs_dir}
      base_url: https://myproject.io/docs/
    YAML

    _, _stderr, status = run_cli('bulk-transform', '--config', config_file)

    expect(status.success?).to be true

    content = File.read(File.join(docs_dir, 'guides', 'sub', 'page.llm.md'))
    expect(content).to include(
      'See [q](https://myproject.io/docs/guides/sub/page.md?tab=2), ' \
      '[qa](https://myproject.io/docs/guides/sub/page.md?tab=3#part) and [self](#self).'
    )

    spaced = File.read(File.join(docs_dir, 'guides', 'my page.llm.md'))
    expect(spaced).to include('See [q](https://myproject.io/docs/guides/my%20page.md?tab=2).')
  end

  it 'leaves links inside code unchanged' do
    docs_dir = File.join(temp_dir, 'docs')
    FileUtils.mkdir_p(File.join(docs_dir, 'guides', 'sub'))

    File.write(File.join(docs_dir, 'guides', 'sub', 'page.md'), <<~MD)
      # Page

      See [intro](../intro.md) and `[ic](../intro.md)`.

      ```md
      [fc](../intro.md)
      ```

      Indented:

          [icb](../intro.md)
    MD

    config_file = File.join(temp_dir, 'config.yml')
    File.write(config_file, <<~YAML)
      docs: #{docs_dir}
      base_url: https://myproject.io/docs/
    YAML

    _, _stderr, status = run_cli('bulk-transform', '--config', config_file)

    expect(status.success?).to be true

    content = File.read(File.join(docs_dir, 'guides', 'sub', 'page.llm.md'))
    expect(content).to eq(<<~MD.chomp)
      # Page

      See [intro](https://myproject.io/docs/guides/intro.md) and `[ic](../intro.md)`.

      ```md
      [fc](../intro.md)
      ```

      Indented:

          [icb](../intro.md)
    MD
  end

  it 'leaves a link whose destination runs into code unchanged' do
    docs_dir = File.join(temp_dir, 'docs')
    FileUtils.mkdir_p(File.join(docs_dir, 'guides'))

    File.write(File.join(docs_dir, 'guides', 'typo.md'), <<~MD)
      See [the API](../api.md for details.

      ```ruby
      client.call(1)
      ```

      Next: [intro](intro.md) and [run](../cli.md "Run `bin/x`").
    MD

    config_file = File.join(temp_dir, 'config.yml')
    File.write(config_file, <<~YAML)
      docs: #{docs_dir}
      base_url: https://myproject.io/docs/
    YAML

    _, _stderr, status = run_cli('bulk-transform', '--config', config_file)

    expect(status.success?).to be true

    content = File.read(File.join(docs_dir, 'guides', 'typo.llm.md'))
    expect(content).to eq(<<~MD.chomp)
      See [the API](../api.md for details.

      ```ruby
      client.call(1)
      ```

      Next: [intro](https://myproject.io/docs/guides/intro.md) and [run](https://myproject.io/docs/cli.md "Run `bin/x`").
    MD
  end

  it 'keeps inline code in link text with simplify_links' do
    docs_dir = File.join(temp_dir, 'docs')
    FileUtils.mkdir_p(File.join(docs_dir, 'guides'))

    File.write(File.join(docs_dir, 'guides', 'api.md'), <<~MD)
      Use [`Config`](config.md) and [see the `run` docs](../cli.md).
    MD

    config_file = File.join(temp_dir, 'config.yml')
    File.write(config_file, <<~YAML)
      docs: #{docs_dir}
      simplify_links: true
    YAML

    _, _stderr, status = run_cli('bulk-transform', '--config', config_file)

    expect(status.success?).to be true

    content = File.read(File.join(docs_dir, 'guides', 'api.llm.md'))
    expect(content).to eq(<<~MD.chomp)
      Use [`Config`](config.md) and [`run`](../cli.md).
    MD
  end

  it 'simplifies links after a destination that runs into code' do
    docs_dir = File.join(temp_dir, 'docs')
    FileUtils.mkdir_p(File.join(docs_dir, 'guides'))

    File.write(File.join(docs_dir, 'guides', 'typo.md'), <<~MD)
      See [the API](../api.md for details.

      ```ruby
      client.call(1)
      ```

      Next: [see the intro docs](intro.md).
    MD

    config_file = File.join(temp_dir, 'config.yml')
    File.write(config_file, <<~YAML)
      docs: #{docs_dir}
      simplify_links: true
    YAML

    _, _stderr, status = run_cli('bulk-transform', '--config', config_file)

    expect(status.success?).to be true

    content = File.read(File.join(docs_dir, 'guides', 'typo.llm.md'))
    expect(content).to eq(<<~MD.chomp)
      See [the API](../api.md for details.

      ```ruby
      client.call(1)
      ```

      Next: [intro](intro.md).
    MD
  end

  it 'fails when directory does not exist' do
    stdout, _stderr, status = run_cli(
      'bulk-transform',
      '--docs', '/nonexistent/directory'
    )

    expect(status.success?).to be false
    expect(status.exitstatus).to eq(1)
    expect(stdout).to include('Documentation path not found')
  end
end
