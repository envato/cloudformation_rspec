# CloudSpec

CloudFormation provides a black-box orchestration model; you feed templates in and infrastructure pops out the other end. This is good in that we design our templates without having to understand how the sausage gets made, but we want a way to test, quickly, what it's actually doing is what we expect.

CloudSpec enables us to do that by providing RSpec matchers to enable you to test your templates against the actual CloudFormation APIs to make sure they work.

## Usage

### Testing template Change Set with Parameters

```ruby
describe 'vpc_template' do
  let(:template_json) { File.read('fixtures/vpc.json') }
  let(:stack) {
    template_body: template_json,
    parameters: {
      "VpcCidr" => cidr,
    }
  }

  context 'with a valid cidr' do
    let(:cidr) { "10.0.0.0/16" }

    it 'creates a vpc' do
      expect(stack).to contain_in_change_set("AWS::EC2::VPC", "vpc")
    end
  end

  context 'with invalid cidr' do
    let(:cidr) { "1.1.1.0/16" }

    it 'fails to create a change set' do
      expect(stack).to have_change_set_failed
    end
  end
end
```

### Testing SparkleFormation templates

```ruby
describe 'vpc_template' do
  let(:stack) {
    compiler: :sparkleformation,
    sparkle_path: "templates",
    template_file: "vpc.rb",
    compile_state: {public_subnets: ["10.0.0.0/24", "10.0.1.0/24"], private_subnets: ["10.0.2.0/24", "10.0.3.0/24"]},
    parameters: {
      "VpcCidr" => cidr,
    }
  }

  context 'with a valid cidr' do
    let(:cidr) { "10.0.0.0/16" }

    it 'creates a vpc' do
      expect(stack).to contain_in_change_set("AWS::EC2::VPC", "vpc")
    end
  end

  context 'with invalid cidr' do
    let(:cidr) { "1.1.1.0/16" }

    it 'fails to create a change set' do
      expect(stack).to have_change_set_failed
    end
  end
end
```

## Limitations

Currently we don't support templates larger than 51,200 bytes, as this requires uploading the template to S3 first.
