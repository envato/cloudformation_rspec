require 'rspec'

module CloudFormationRSpec::Matchers::ChangeSet
  def generate_change_set(stack)
    if stack[:compiler] == :sparkleformation
      change_set_result = CloudFormationRSpec::ChangeSet.from_sparkleformation_template(
        sparkle_path: stack[:sparkle_path],
        template_file: stack[:template_file],
        compile_state: stack[:compile_state],
        parameters: stack[:parameters]
      )
    else
      if !stack[:template_body]
        raise ArgumentError, "You must pass either :template_body or set :compiler and pass in compiler specific options"
      end
      change_set_result = CloudFormationRSpec::ChangeSet.from_cloudformation_template(template_body: stack[:template_body], parameters: stack[:parameters])
    end
  end
end

RSpec::Matchers.define :contain_in_change_set do |resource_type, resource_id|
  include CloudFormationRSpec::Matchers::ChangeSet

  match do |stack|
    if !stack.is_a?(Hash)
      raise ArgumentError, "You must pass a hash to this expectation"
    end

    change_set_result = generate_change_set(stack)

    if change_set_result.status == 'FAILED'
      @error = "Change set creation failed: #{change_set_result.status_reason}"
      return false
    end

    if !change_set_result.changes.any? { |change| change.resource_change.resource_type == resource_type }
      @error = "Change set does not include resource type #{resource_type}"
      return false
    end

    if !change_set_result.changes.any? { |change| change.resource_change.logical_resource_id == resource_id }
      @error = "Change set does not include a resource type #{resource_type} with the id #{resource_id}"
      return false
    end
    true
  end

  failure_message do
    @error
  end
end

RSpec::Matchers.define :have_change_set_failed do
  include CloudFormationRSpec::Matchers::ChangeSet

  match do |stack|
    change_set_result = generate_change_set(stack)
  
    if change_set_result.status != 'FAILED'
      @error = "Change set creation succeeded"
      return false
    end
  
    true
  end

  failure_message do
    @error
  end
end
