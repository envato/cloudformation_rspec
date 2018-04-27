require 'spec_helper'

describe 'contain_in_change_set' do
  let(:change_set_mock) { instance_double(CloudFormationRSpec::ChangeSet) }
  let(:stack) {{
    template_body: '{"Parameters": {"VpcCidr": {"Type": "String"}},"Resources": {"Foo": {"Type" : "AWS::EC2::VPC","Properties": {"Cidr" : {"Ref": "VpcCidr"}}}}}',
    parameters: {
      "VpcCidr" => "10.0.0.0/16"
    }
  }}
  let(:sparkle_stack) {{
    compiler: :sparkleformation,
    template_file: File.join("templates", "vpc.rb"),
    compile_state: {public_subnets: ["10.0.0.0/24", "10.0.1.0/24"], private_subnets: ["10.0.2.0/24", "10.0.3.0/24"]},
    parameters: {
      "VpcCidr" => "10.0.0.0/16",
    }
  }}
  let(:uuid) { "d7ad0965-7395-4660-b607-47b13b1d16c2" }
  let(:web_server_change_mock) { instance_double(CloudFormationRSpec::ResourceChange) }
  let(:vpc_change_mock) { instance_double(CloudFormationRSpec::ResourceChange) }
  before do
    allow(CloudFormationRSpec::ChangeSet).to receive(:new).and_return(change_set_mock)
    allow(CloudFormationRSpec::ChangeSet).to receive(:from_sparkleformation_template).and_return(change_set_mock)
    allow(CloudFormationRSpec::ChangeSet).to receive(:from_cloudformation_template).and_return(change_set_mock)
    allow(SecureRandom).to receive(:uuid).and_return(uuid)
  end

  after do
    CloudFormationRSpec::ChangeSet.flush_cache
  end

  context 'a valid cloudformation template' do
    before do
      allow(change_set_mock).to receive(:status).and_return("CREATE_COMPLETE")
      allow(change_set_mock).to receive(:changes).and_return([vpc_change_mock, web_server_change_mock])
      allow(web_server_change_mock).to receive(:resource_type).and_return("AWS::EC2::Instance")
      allow(web_server_change_mock).to receive(:logical_resource_id).and_return("WebServer")
      allow(vpc_change_mock).to receive(:resource_type).and_return("AWS::EC2::VPC")
      allow(vpc_change_mock).to receive(:logical_resource_id).and_return("vpc")
    end

    it 'succeeds when there is a matching resource' do
      expect(stack).to contain_in_change_set("AWS::EC2::VPC", "vpc")
    end

    it 'fails when there is no matching resource id' do
      expect(stack).not_to contain_in_change_set("AWS::EC2::VPC", "foo")
    end

    it 'fails when there is no matching resource type' do
      expect(stack).not_to contain_in_change_set("AWS::EC2::Foo", "vpc")
    end
  end

  context 'an invalid sparkleformation template' do
    let(:template_file) { File.join('spec', 'fixtures', 'invalid_sparkle_vpc_template.rb') }
    let(:stack) {{
      compiler: :sparkleformation,
      template_file: template_file,
      compile_state: {}
    }}
    before do
      allow(CloudFormationRSpec::ChangeSet).to receive(:from_sparkleformation_template).and_raise(CloudFormationRSpec::Sparkle::InvalidSparkleTemplate)
      allow(change_set_mock).to receive(:status).and_return("FAILED")
    end

    it 'fails' do
      expect { expect(stack).not_to contain_in_change_set("AWS::EC2::Foo", "vpc") }.to raise_error(CloudFormationRSpec::Sparkle::InvalidSparkleTemplate)
    end
  end
end

describe 'have_change_set_failed' do
  let(:change_set_mock) { instance_double(CloudFormationRSpec::ChangeSet) }
  let(:stack) {{
    template_body: '{"Parameters": {"VpcCidr": {"Type": "String"}},"Resources": {"Foo": {"Type" : "AWS::EC2::VPC","Properties": {"Cidr" : {"Ref": "VpcCidr"}}}}}',
    parameters: {
      "VpcCidr" => "10.0.0.0/16"
    }
  }}
  let(:sparkle_stack) {{
    compiler: :sparkleformation,
    template_file: File.join("templates", "vpc.rb"),
    compile_state: {public_subnets: ["10.0.0.0/24", "10.0.1.0/24"], private_subnets: ["10.0.2.0/24", "10.0.3.0/24"]},
    parameters: {
      "VpcCidr" => "10.0.0.0/16",
    }
  }}
  before do
    allow(CloudFormationRSpec::ChangeSet).to receive(:new).and_return(change_set_mock)
    allow(CloudFormationRSpec::ChangeSet).to receive(:from_sparkleformation_template).and_return(change_set_mock)
    allow(CloudFormationRSpec::ChangeSet).to receive(:from_cloudformation_template).and_return(change_set_mock)
  end

  after do
    CloudFormationRSpec::ChangeSet.flush_cache
  end

  context 'a valid cloudformation template' do
    before do
      allow(change_set_mock).to receive(:status).and_return("CREATE_COMPLETE")
    end

    it 'fails' do
      expect(stack).not_to have_change_set_failed
    end
  end

  context 'an invalid change' do
    before do
      allow(change_set_mock).to receive(:status).and_return("FAILED")
    end

    it 'succeeds' do
      expect(stack).to have_change_set_failed
    end
  end

  context 'an invalid sparkleformation template' do
    let(:template_file) { File.join('spec', 'fixtures', 'invalid_sparkle_vpc_template.rb') }
    let(:stack) {{
      compiler: :sparkleformation,
      template_file: template_file,
      compile_state: {}
    }}
    before do
      allow(CloudFormationRSpec::ChangeSet).to receive(:from_sparkleformation_template).and_raise(CloudFormationRSpec::Sparkle::InvalidSparkleTemplate)
      allow(change_set_mock).to receive(:status).and_return("FAILED")
    end

    it 'fails' do
      expect { expect(stack).to have_change_set_failed }.to raise_error(CloudFormationRSpec::Sparkle::InvalidSparkleTemplate)
    end
  end
end
