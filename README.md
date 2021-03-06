# CloudFormation RSpec

CloudFormation provides a black-box orchestration model; you feed templates in and infrastructure pops out the other end. This is good in that we design our templates without having to understand how the sausage gets made, but we want a way to test, quickly, what it's actually doing is what we expect.

CloudFormation RSpec enables us to use RSpec matchers test your templates against the actual CloudFormation APIs without creating actual infrastructure. This is a tradeoff to get faster feedback (typically in under 2 minutes) without waiting for CloudFormation stacks to build and is designed to complement but not replace Acceptance Testing.

## Usage

### Testing template Change Set with Parameters

```ruby
describe 'vpc_template' do
  let(:template_json) { File.read('fixtures/vpc.json') }
  let(:stack) {{
    template_body: template_json,
    parameters: {
      "VpcCidr" => cidr,
    }
  }}

  it 'is valid' do
    expect(template_json).to be_valid
  end

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
    template_file: "templates/vpc.rb",
    compile_state: {public_subnets: ["10.0.0.0/24", "10.0.1.0/24"], private_subnets: ["10.0.2.0/24", "10.0.3.0/24"]},
    parameters: {
      "VpcCidr" => cidr,
    }
  }

  it 'is valid' do
    expect(stack).to be_valid_sparkleformation
  end

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

## Development Status

In production use

## Maintainers

Patrick Robinson (@patrobinson)

## Limitations

Currently we don't support templates larger than 51,200 bytes, as this requires uploading the template to S3 first.

## Contributing

For bug fixes, documentation changes, and small features:  
1. Fork it ( https://github.com/envato/cloudformation_rspec/fork )  
2. Create your feature branch (`git checkout -b my-new-feature`)  
3. Commit your changes (`git commit -am 'Add some feature'`)  
4. Push to the branch (`git push origin my-new-feature`)  
5. Create a new Pull Request  

For larger new features: Do everything as above, but first also make contact with the project maintainers to be sure your change fits with the project direction and you won't be wasting effort going in the wrong direction
