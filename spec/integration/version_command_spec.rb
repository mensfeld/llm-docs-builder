# frozen_string_literal: true

require 'spec_helper'
require 'open3'

RSpec.describe 'version command', :integration do
  let(:cli_path) { File.expand_path('../../bin/llms-txt', __dir__) }

  def run_cli(*args)
    cmd = "bundle exec #{cli_path} #{args.join(' ')}"
    stdout, stderr, status = Open3.capture3(cmd)
    [stdout, stderr, status]
  end

  it 'displays version information' do
    stdout, _stderr, status = run_cli('version')

    expect(status.success?).to be true
    expect(stdout).to match(/llms-txt version \d+\.\d+\.\d+/)
  end

  it 'shows error for unknown command' do
    stdout, _stderr, status = run_cli('unknown-command')

    expect(status.success?).to be false
    expect(status.exitstatus).to eq(1)
    expect(stdout).to include('Unknown command: unknown-command')
  end
end
