require 'spec_helper'

describe CloudFormationRSpec::ChangeSet do
  let(:template_body) { '{"Description": "Foo"}' }
  let(:parameters) { {"VpcCidr" => "10.0.0.0/16"} }
  let(:cf_stub) { instance_double(Aws::CloudFormation::Client) }
  let(:change_set_mock) { instance_double(Aws::CloudFormation::Types::DescribeChangeSetOutput) }
  let(:change_set_create_mock) { instance_double(Aws::CloudFormation::Types::CreateChangeSetOutput) }
  let(:stacks_mock) { instance_double(Aws::CloudFormation::Types::DescribeStacksOutput) }
  let(:stack_mock) { instance_double(Aws::CloudFormation::Types::Stack) }
  let(:aws_change_mock) { instance_double(Aws::CloudFormation::Types::Change) }
  let(:aws_resource_change_mock) { instance_double(Aws::CloudFormation::Types::ResourceChange) }
  let(:uuid) { "a7ad0965-7395-4660-b607-47b13b1d16c2" }

  before do
    allow(Aws::CloudFormation::Client).to receive(:new).and_return(cf_stub)
    allow(cf_stub).to receive(:create_change_set).and_return(change_set_create_mock)
    allow(change_set_create_mock).to receive(:id).and_return("123")
    allow(cf_stub).to receive(:delete_stack)
    allow(cf_stub).to receive(:delete_change_set)
    allow(cf_stub).to receive(:describe_change_set).and_return(change_set_mock)
    allow(cf_stub).to receive(:describe_stacks).and_return(stacks_mock)
    allow(cf_stub).to receive(:wait_until).and_return(true)
    allow(change_set_mock).to receive(:status).and_return("CREATE_COMPLETE")
    allow(change_set_mock).to receive(:status_reason).and_return("Success")
    allow(change_set_mock).to receive(:changes).and_return([aws_change_mock])
    allow(aws_change_mock).to receive(:resource_change).and_return(aws_resource_change_mock)
    allow(stacks_mock).to receive(:stacks).and_return([stack_mock])
    allow(stack_mock).to receive(:stack_status).and_return("REVIEW_IN_PROGRESS")
    allow(aws_resource_change_mock).to receive(:resource_type).and_return("AWS::EC2::VPC")
    allow(aws_resource_change_mock).to receive(:logical_resource_id).and_return("Foo")
    allow(SecureRandom).to receive(:uuid).and_return(uuid)
  end

  after do
    CloudFormationRSpec::ChangeSet.flush_cache
  end

  context 'a sparkleformation template' do
    let(:template_file) { File.join("spec", "fixtures", "vpc.rb") }
    let(:parameters) { {} }
    let(:compile_state) { {} }
    subject { described_class.from_sparkleformation_template(template_file: template_file, compile_state: compile_state, parameters: parameters) }

    context 'that does compile' do
      let(:template_file) { File.join('spec', 'fixtures', 'valid_sparkle_vpc_template.rb') }

      context 'with parameters' do
        let(:parameters) { {"VpcCidr" => "10.0.0.0/16"} }
        it 'succeeds' do
          expect(subject.status).to eq("CREATE_COMPLETE")
        end
      end

      context 'with compile state' do
        let(:compile_state) { {public_subnets: ["10.0.0.0/24", "10.0.1.0/24"], private_subnets: ["10.0.2.0/24", "10.0.3.0/24"]} }
        it 'succeeds' do
          expect(subject.status).to eq("CREATE_COMPLETE")
        end
      end

      context 'with no parameters or compile state' do
        it 'succeeds' do
          expect(subject.status).to eq("CREATE_COMPLETE")
        end
      end
    end
  end

  context 'a valid change set' do
    subject(:subject_default) { described_class.new(template_body: template_body, parameters: parameters) }
    subject(:cached_subject_default) { described_class.new(template_body: template_body, parameters: parameters) }
    subject(:different_parameters) { described_class.new(template_body: template_body, parameters: {}) }
    subject(:different_template) { described_class.new(template_body: "{}", parameters: parameters) }

    it 'calls create_change_set with the required parameters' do
      expect(cf_stub).to receive(:create_change_set).with(
        change_set_name: "CloudFormationRSpec-#{uuid}",
        stack_name: "CloudFormationRSpec-#{uuid}",
        change_set_type: 'CREATE',
        template_body: template_body,
        parameters: [
          {
            parameter_key:  "VpcCidr",
            parameter_value: "10.0.0.0/16"
          }
        ],
        capabilities: ['CAPABILITY_IAM', 'CAPABILITY_NAMED_IAM'],
      )
      subject_default.create_change_set
    end

    it 'caches the change set between runs' do
      expect(cf_stub).to receive(:create_change_set).once
      subject_default.create_change_set
      cached_subject_default.create_change_set
    end

    it 'restores the status from the cached run' do
      subject_default.create_change_set
      cached_subject_default.create_change_set
      expect(cached_subject_default.status).to eq("CREATE_COMPLETE")
    end

    it 'restores the changes from the cached run' do
      subject_default.create_change_set
      cached_subject_default.create_change_set
      expect(cached_subject_default.changes).to match_array([CloudFormationRSpec::ResourceChange.new("AWS::EC2::VPC", "Foo")])
    end

    it 'does not cache change sets when parameters are different' do
      expect(cf_stub).to receive(:create_change_set).twice
      subject_default.create_change_set
      different_parameters.create_change_set
    end

    it 'does not cache change sets when the template is different' do
      expect(cf_stub).to receive(:create_change_set).twice
      subject_default.create_change_set
      different_template.create_change_set
    end

    it 'deletes the stack and change set' do
      expect(cf_stub).to receive(:delete_stack)
      expect(cf_stub).to receive(:delete_change_set)
      subject_default.create_change_set
    end
  end

  context 'an invalid change' do
    subject { described_class.new(template_body: template_body, parameters: parameters) }
    before do
      allow(cf_stub).to receive(:wait_until).and_raise(Aws::Waiters::Errors::WaiterFailed)
      allow(change_set_mock).to receive(:status).and_return("FAILED")
      allow(change_set_mock).to receive(:status_reason).and_return("FAILED")
    end

    it 'just deletes the change set' do
      expect(cf_stub).not_to receive(:delete_stack)
      expect(cf_stub).to receive(:delete_change_set)
      subject.create_change_set
    end
  end
end
