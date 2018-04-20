require 'rspec'
require 'aws-sdk-cloudformation'

RSpec::Matchers.define :be_valid do
  match do |cf_template|
    client = Aws::CloudFormation::Client.new
    begin
      client.validate_template(template_body: cf_template)
    rescue Aws::CloudFormation::Errors::ValidationError => e
      @error = e.message
      return false
    end
    true
  end

  failure_message do
    @error
  end
end
