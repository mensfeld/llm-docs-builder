# frozen_string_literal: true

require 'llm_docs_builder/config'
require 'tempfile'
require 'yaml'

RSpec.describe LlmDocsBuilder::Config do
  describe '#dig' do
    it 'accesses nested configuration values' do
      config_file = Tempfile.new(['config', '.yml'])
      config_file.write(YAML.dump({ 'nested' => { 'key' => 'value' } }))
      config_file.close

      config = described_class.new(config_file.path)
      expect(config.dig(:nested, :key)).to eq('value')

      config_file.unlink
    end

    it 'returns nil for missing nested keys' do
      config_file = Tempfile.new(['config', '.yml'])
      config_file.write(YAML.dump({ 'nested' => { 'key' => 'value' } }))
      config_file.close

      config = described_class.new(config_file.path)
      expect(config.dig(:nested, :missing)).to be_nil

      config_file.unlink
    end
  end

  describe '#exists?' do
    it 'returns true when config file exists' do
      config_file = Tempfile.new(['config', '.yml'])
      config_file.write(YAML.dump({ 'key' => 'value' }))
      config_file.close

      config = described_class.new(config_file.path)
      expect(config.exists?).to be true

      config_file.unlink
    end

    it 'returns false when no config file specified' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          config = described_class.new
          expect(config.exists?).to be_falsey
        end
      end
    end
  end

  describe '#merge_with_options' do
    it 'includes body parameter from config file' do
      config_file = Tempfile.new(['config', '.yml'])
      config_file.write(YAML.dump({ 'body' => 'Custom body content from config' }))
      config_file.close

      config = described_class.new(config_file.path)
      merged = config.merge_with_options({})

      expect(merged[:body]).to eq('Custom body content from config')

      config_file.unlink
    end

    it 'allows CLI options to override body parameter' do
      config_file = Tempfile.new(['config', '.yml'])
      config_file.write(YAML.dump({ 'body' => 'Config body' }))
      config_file.close

      config = described_class.new(config_file.path)
      merged = config.merge_with_options({ body: 'CLI body override' })

      expect(merged[:body]).to eq('CLI body override')

      config_file.unlink
    end
  end

  describe 'error handling' do
    it 'raises GenerationError for invalid YAML syntax' do
      config_file = Tempfile.new(['config', '.yml'])
      config_file.write("invalid: yaml: syntax:\n  broken")
      config_file.close

      expect do
        described_class.new(config_file.path)
      end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /Invalid YAML/)

      config_file.unlink
    end

    it 'raises GenerationError for file read errors' do
      config_file = Tempfile.new(['config', '.yml'])
      config_file.write(YAML.dump({ 'key' => 'value' }))
      config_file.close
      path = config_file.path
      config_file.unlink

      # Simulate error by trying to read non-existent file after setting it in the config
      # We need to mock YAML.load_file to simulate read errors
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(path).and_return(true)
      allow(YAML).to receive(:load_file).with(path).and_raise(StandardError.new('Permission denied'))

      expect do
        described_class.new(path)
      end.to raise_error(LlmDocsBuilder::Errors::GenerationError, /Failed to load config file/)
    end
  end
end
