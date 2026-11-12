# frozen_string_literal: true

RSpec.describe 'validate command' do
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

  it 'validates valid llms.txt file' do
    # Create valid llms.txt file
    valid_file = File.join(temp_dir, 'valid.txt')
    File.write(valid_file, <<~CONTENT)
      # Valid Project

      > A valid llms.txt file

      ## Documentation

      - [Docs](docs/): Documentation
    CONTENT

    # Run validate command
    stdout, _stderr, status = run_cli('validate', '--docs', valid_file)

    # Verify success
    expect(status.success?).to be true
    expect(stdout).to include('Valid llms.txt file')
  end

  it 'rejects invalid llms.txt file' do
    # Create invalid llms.txt file
    invalid_file = File.join(temp_dir, 'invalid.txt')
    File.write(invalid_file, 'Invalid content without proper structure')

    # Run validate command
    stdout, _stderr, status = run_cli('validate', '--docs', invalid_file)

    # Verify failure
    expect(status.success?).to be false
    expect(status.exitstatus).to eq(1)
    expect(stdout).to include('Invalid llms.txt file')
    expect(stdout).to include('Errors:')
  end

  it 'reads llms.txt from the current directory without --docs' do
    write_cwd_llms_txt

    stdout, _stderr, status = run_cli_in(temp_dir, 'validate')

    expect(status.success?).to be true
    expect(stdout).to include('Valid llms.txt file')
  end

  it 'reads llms.txt, not the config docs directory, when the config sets docs' do
    write_cwd_llms_txt
    FileUtils.mkdir_p(File.join(temp_dir, 'docs'))
    File.write(File.join(temp_dir, 'llm-docs-builder.yml'), "docs: ./docs\n")

    stdout, _stderr, status = run_cli_in(temp_dir, 'validate')

    expect(status.success?).to be true
    expect(stdout).to include('Valid llms.txt file')
  end
end
