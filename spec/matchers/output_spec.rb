require 'spec_helper'

describe 'have_output_including' do
  context 'sparkleformation template' do
    let(:template_file) { File.join('spec', 'fixtures', 'valid_sparkle_vpc_template.rb') }
    let(:stack) {{
      compiler: :sparkleformation,
      template_file: template_file,
      compile_state: {}
    }}

    it 'has a vpc_id output' do
      expect(stack).to have_output_including("VpcId")
    end

    it 'has vpc_cidr output' do
      expect(stack).to have_output_including("VpcCidr")
    end

    it 'does not have subnet_id output' do
      expect(stack).not_to have_output_including("SubnetId")
    end
  end

  context 'yaml template' do
    let(:template_body) { File.read(File.join('spec', 'fixtures', 'valid_vpc_template.yml')) }

    it 'has a vpc_id output' do
      expect(template_body).to have_output_including("VpcId")
    end

    it 'does not have vpc_cidr output' do
      expect(template_body).not_to have_output_including("VpcCidr")
    end
  end

  context 'json template' do
    let(:template_body) { File.read(File.join('spec', 'fixtures', 'valid_vpc_template.json')) }

    it 'has a vpc_id output' do
      expect(template_body).to have_output_including("VpcId")
    end

    it 'does not have vpc_cidr output' do
      expect(template_body).not_to have_output_including("VpcCidr")
    end

    it 'provides a diff of the outputs' do
      expect { expect(template_body).not_to have_output_including("VpcId") }.to raise_error(RSpec::Expectations::ExpectationNotMetError, 'expected ["VpcId"] not to have output including "VpcId"')
    end
  end

  context 'garbage template' do
    let(:template_body) { '   {lkajdflkasdjf' }
    it 'raises an ArgumentError' do
      expect{ expect(template_body).to have_output_including("VpcId") }.to raise_error(SyntaxError)
    end
  end
end
