# frozen_string_literal: true

RSpec.describe 'version command' do
  let(:cli_path) { File.expand_path('../../bin/llm-docs-builder', __dir__) }

  def run_cli(*args)
    cmd = "bundle exec #{cli_path} #{args.join(' ')}"
    stdout, stderr, status = Open3.capture3(cmd)
    [stdout, stderr, status]
  end

  it 'displays version information' do
    stdout, _stderr, status = run_cli('version')

    expect(status.success?).to be true
    expect(stdout).to match(/llm-docs-builder version \d+\.\d+\.\d+/)
  end

  it 'shows error for unknown command' do
    stdout, stderr, status = run_cli('unknown-command')

    expect(status.success?).to be false
    expect(status.exitstatus).to eq(1)
    expect(stderr).to include('Unknown command: unknown-command')
    expect(stderr).to include("Run 'llm-docs-builder --help' for usage information")
    expect(stdout).to be_empty
  end

  it 'shows a usage error for an unknown option' do
    stdout, stderr, status = run_cli('transform', '--foo')

    expect(status.exitstatus).to eq(1)
    expect(stderr).to eq(<<~ERR)
      Error: invalid option: --foo
      Run 'llm-docs-builder --help' for usage information
    ERR
    expect(stdout).to be_empty
  end
end
