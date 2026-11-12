# frozen_string_literal: true

RSpec.describe 'parse command' do
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

  def run_cli_in(dir, *args)
    cmd = "bundle exec #{cli_path} #{args.join(' ')}"
    env = { 'BUNDLE_GEMFILE' => File.expand_path('../../Gemfile', __dir__) }
    stdout, stderr, status = Open3.capture3(env, cmd, chdir: dir)
    [stdout, stderr, status]
  end

  def write_cwd_llms_txt
    File.write(File.join(temp_dir, 'llms.txt'), <<~CONTENT)
      # Cwd Project

      > Read from the current directory

      ## Documentation

      - [Docs](docs/README.md): Documentation
    CONTENT
  end

  it 'parses llms.txt file and displays information' do
    # Create llms.txt file
    llms_file = File.join(temp_dir, 'llms.txt')
    File.write(llms_file, <<~CONTENT)
      # Test Project

      > A sample project for testing

      ## Documentation

      - [README](docs/README.md): Project overview
      - [API Reference](docs/api.md): API documentation
    CONTENT

    # Run parse command with verbose flag
    stdout, _stderr, status = run_cli('parse', '--docs', llms_file, '--verbose')

    # Verify parsing output
    expect(status.success?).to be true
    expect(stdout).to include('Title: Test Project')
    expect(stdout).to include('Description: A sample project for testing')
    expect(stdout).to include('Documentation Links:')
  end

  it 'fails when file does not exist' do
    stdout, _stderr, status = run_cli('parse', '--docs', '/nonexistent/llms.txt')

    expect(status.success?).to be false
    expect(status.exitstatus).to eq(1)
    expect(stdout).to include('File not found')
  end

  it 'reads llms.txt from the current directory without --docs' do
    write_cwd_llms_txt

    stdout, _stderr, status = run_cli_in(temp_dir, 'parse', '--verbose')

    expect(status.success?).to be true
    expect(stdout).to include('Title: Cwd Project')
  end

  it 'reads llms.txt, not the config docs directory, when the config sets docs' do
    write_cwd_llms_txt
    FileUtils.mkdir_p(File.join(temp_dir, 'docs'))
    File.write(File.join(temp_dir, 'llm-docs-builder.yml'), "docs: ./docs\n")

    stdout, _stderr, status = run_cli_in(temp_dir, 'parse', '--verbose')

    expect(status.success?).to be true
    expect(stdout).to include('Title: Cwd Project')
  end
end
