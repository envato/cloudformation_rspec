require 'aws-sdk-cloudformation'
require 'open3'

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

  def lint_cf_template(template_body)
    # Issue a warning if cfn-lint is not installed, but pass the test
    unless cfn_lint_available
      warn "Failed to run cfn-lint, do you have it installed and available in $PATH?"
      true
    end

    Tempfile.open(['cfn-lint', '.json']) do |f|
      f.write(template_body)
      f.flush
      _, stderr, status = Open3.capture3('cfn-lint', f.path)
      if !status
        @error = stderr
      end
      status
    end
  end

  def cfn_lint_available
    !system('cfn-lint', '--version').nil?
  end
end

RSpec::Matchers.define :be_valid do
  include CloudFormationRSpec::Matchers::Validate
  match do |cf_template|
    validate_cf_template(cf_template) && lint_cf_template(cf_template)
  end

  failure_message do
    @error
  end
end

RSpec::Matchers.define :be_valid_sparkleformation do
  include CloudFormationRSpec::Matchers::Validate
  match do |stack|
    if !stack.is_a?(Hash) || !stack[:template_file]
      raise ArgumentError, "You must pass a hash to this expectation with at least the :template_file option"
    end

    stack[:compile_state] ||= {}

    begin
      template_body = CloudFormationRSpec::Sparkle.compile_sparkle_template(stack[:template_file], stack[:compile_state])
    rescue CloudFormationRSpec::Sparkle::InvalidTemplate => error
      @error = error
      return false
    end
    validate_cf_template(template_body) && lint_cf_template(template_body)
  end

  failure_message do
    @error
  end
end
