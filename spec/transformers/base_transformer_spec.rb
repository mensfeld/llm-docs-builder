# frozen_string_literal: true

require 'llm_docs_builder/transformers/base_transformer'

RSpec.describe LlmDocsBuilder::Transformers::BaseTransformer do
  # Create a test class that includes the module
  let(:test_class) do
    Class.new do
      include LlmDocsBuilder::Transformers::BaseTransformer
    end
  end

  let(:instance) { test_class.new }

  describe '#transform' do
    it 'raises NotImplementedError when not overridden' do
      expect do
        instance.transform('content')
      end.to raise_error(NotImplementedError, /must implement #transform/)
    end
  end

  describe '#should_transform?' do
    it 'returns true by default' do
      expect(instance.should_transform?({})).to be true
    end

    it 'returns true with options' do
      expect(instance.should_transform?(some_option: true)).to be true
    end
  end
end
