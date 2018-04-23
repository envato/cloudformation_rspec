require 'spec_helper'

describe CloudFormationRSpec::Sparkle do
  let(:template_file) { "vpc.rb" }
  let(:sparkle_path) { "spec/fixtures" }
  let(:compile_state) { {} }
  subject { described_class.compile_sparkle_template(sparkle_path, template_file, compile_state) }

  context 'that doesnt compile to sparkleformation' do
    before do
      allow(SparkleFormation).to receive(:compile).and_raise(RuntimeError)
    end

    it 'raises InvalidSparkleTemplate' do
      expect { subject }.to raise_error(described_class::InvalidSparkleTemplate)
    end
  end

  context 'that doesnt compile to cloudformation' do
    let(:sparkle_stub) { instance_double(SparkleFormation) }
    before do
      allow(SparkleFormation).to receive(:compile).and_return(sparkle_stub)
      allow(sparkle_stub).to receive(:compile_state=)
      allow(sparkle_stub).to receive(:to_json).and_raise(RuntimeError)
    end

    it 'raises InvalidCloudFormationTemplate' do
      expect { subject }.to raise_error(described_class::InvalidCloudFormationTemplate)
    end
  end
end
