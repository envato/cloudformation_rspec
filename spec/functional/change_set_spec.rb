require 'spec_helper'

describe 'have_change_set_failed' do
  let(:cf_stub) { instance_double(Aws::CloudFormation::Client) }
  let(:change_set_mock) { instance_double(Aws::CloudFormation::Types::DescribeChangeSetOutput) }
  let(:stack) {{
    template_body: '{"Parameters": {"VpcCidr": {"Type": "String"}, "Resources": {"Foo": {"Type" : "AWS::EC2::VPC","Properties" : {"Cidr" : {"Ref": "VpcCidr"}}}}}',
    parameters: {
      "VpcCidr" => "10.0.0.0/16"
    }
  }}
  let(:change_set_create_mock) { instance_double(Aws::CloudFormation::Types::CreateChangeSetOutput) }
  before do
    allow(Aws::CloudFormation::Client).to receive(:new).and_return(cf_stub)
    allow(cf_stub).to receive(:create_change_set).and_return(change_set_create_mock)
    allow(change_set_create_mock).to receive(:id).and_return("123")
    allow(cf_stub).to receive(:wait_until)
    allow(cf_stub).to receive(:delete_stack)
    allow(cf_stub).to receive(:delete_change_set)
    allow(cf_stub).to receive(:describe_change_set).and_return(change_set_mock)
  end

  context 'the change set is valid' do
    let(:web_server_change_mock) { instance_double(Aws::CloudFormation::Types::Change) }
    let(:web_server_resource_change_mock) { instance_double(Aws::CloudFormation::Types::ResourceChange) }
    let(:vpc_change_mock) { instance_double(Aws::CloudFormation::Types::Change) }
    let(:vpc_resource_change_mock) { instance_double(Aws::CloudFormation::Types::ResourceChange) }
    before do
      allow(change_set_mock).to receive(:status).and_return("CREATE_COMPLETE")
      allow(change_set_mock).to receive(:changes).and_return([vpc_change_mock, web_server_change_mock])
      allow(web_server_change_mock).to receive(:resource_change).and_return(web_server_resource_change_mock)
      allow(web_server_resource_change_mock).to receive(:resource_type).and_return("AWS::EC2::Instance")
      allow(web_server_resource_change_mock).to receive(:logical_resource_id).and_return("WebServer")
      allow(vpc_change_mock).to receive(:resource_change).and_return(vpc_resource_change_mock)
      allow(vpc_resource_change_mock).to receive(:resource_type).and_return("AWS::EC2::VPC")
      allow(vpc_resource_change_mock).to receive(:logical_resource_id).and_return("vpc")
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

    it 'deletes the stack and change set' do
      expect(cf_stub).to receive(:delete_stack)
      expect(cf_stub).to receive(:delete_change_set)
      expect(stack).not_to have_change_set_failed
    end
  end

  context 'the change is not valid' do
    let(:template) { '{"Description": "My Template"}' }
    before do
      allow(cf_stub).to receive(:wait_until).and_raise(Aws::Waiters::Errors::WaiterFailed)
      allow(change_set_mock).to receive(:status).and_return("FAILED")
    end

    it 'fails' do
      expect(template).to have_change_set_failed
    end

    it 'just deletes the change set' do
      expect(cf_stub).not_to receive(:delete_stack)
      expect(cf_stub).to receive(:delete_change_set)
      expect(stack).to have_change_set_failed
    end
  end
end
