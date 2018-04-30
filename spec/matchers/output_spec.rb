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
end
