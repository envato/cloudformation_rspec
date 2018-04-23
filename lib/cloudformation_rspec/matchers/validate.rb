require 'rspec'
require 'aws-sdk-cloudformation'

module CloudFormationRSpec::Matchers::Validate
  def validate_cf_template(template_body)
    client = Aws::CloudFormation::Client.new
    begin
      client.validate_template(template_body: template_body)
    rescue Aws::CloudFormation::Errors::ValidationError => e
      @error = e.message
      return false
    end
    true
  end
end

RSpec::Matchers.define :be_valid do
  include CloudFormationRSpec::Matchers::Validate
  match do |cf_template|
    validate_cf_template(cf_template)
  end

  failure_message do
    @error
  end
end

RSpec::Matchers.define :be_valid_sparkleformation do
  include CloudFormationRSpec::Matchers::Validate
  match do |template_file|
    begin
      template_body = CloudFormationRSpec::Sparkle.compile_sparkle_template(template_file, {})
    rescue CloudFormationRSpec::Sparkle::InvalidSparkleTemplate, CloudFormationRSpec::Sparkle::InvalidCloudFormationTemplate => error
      @error = error
      return false
    end
    validate_cf_template(template_body)
  end

  failure_message do
    @error
  end
end
