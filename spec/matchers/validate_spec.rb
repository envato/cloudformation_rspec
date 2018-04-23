require 'spec_helper'

describe 'be_valid' do
  let(:cf_stub) { instance_double(Aws::CloudFormation::Client) }
  before do
    allow(Aws::CloudFormation::Client).to receive(:new).and_return(cf_stub)
  end

  context 'the stack is valid' do
    before do
      allow(cf_stub).to receive(:validate_template)
    end

    it 'succeeds' do
      expect('{"Description": "My Template", "Resources": {"Foo": {"Type" : "AWS::EC2::Instance","Properties" : {"ImageId" : "ami-2f726546"}}}}').to be_valid
    end
  end

  context 'the stack is not valid' do
    let(:template) { '{"Description": "My Template"}' }
    before do
      allow(cf_stub).to receive(:validate_template).with(template_body: template).and_raise(Aws::CloudFormation::Errors::ValidationError.new(Seahorse::Client::RequestContext.new(), "Template format error: At least one Resources member must be defined."))
    end

    it 'fails' do
      expect(template).not_to be_valid
    end
  end
end

describe 'be_valid_sparkleformation' do
  let(:cf_stub) { instance_double(Aws::CloudFormation::Client) }
  before do
    allow(Aws::CloudFormation::Client).to receive(:new).and_return(cf_stub)
  end

  context 'the stack is valid' do
    let(:template_file) { File.join('spec', 'fixtures', 'valid_sparkle_vpc_template.rb') }
    before do
      allow(cf_stub).to receive(:validate_template)
    end

    it 'succeeds' do
      expect(template_file).to be_valid_sparkleformation
    end
  end

  context 'the stack is not valid cloudformation' do
    let(:template_file) { File.join('spec', 'fixtures', 'valid_sparkle_vpc_template.rb') }
    before do
      allow(cf_stub).to receive(:validate_template).and_raise(Aws::CloudFormation::Errors::ValidationError.new(Seahorse::Client::RequestContext.new(), "Template format error: At least one Resources member must be defined."))
    end

    it 'fails' do
      expect(template_file).not_to be_valid_sparkleformation
    end
  end

  context 'the stack is not valid sparkleformation' do
    let(:template_file) { File.join('spec', 'fixtures', 'invalid_sparkle_vpc_template.rb') }
    before do
      allow(cf_stub).to receive(:validate_template)
    end

    it 'fails' do
      expect(cf_stub).not_to receive(:validate_template)
      expect(template_file).not_to be_valid_sparkleformation
    end
  end
end
