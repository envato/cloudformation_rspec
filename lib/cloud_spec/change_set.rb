require 'rspec'
require 'aws-sdk-cloudformation'
require 'securerandom'

module CloudSpec::ChangeSet
  END_STATES = [
    'CREATE_COMPLETE',
    'DELETE_COMPLETE',
    'FAILED'
  ]

  def create_change_set(stack)
    if !stack.is_a?(Hash) || stack[:template_body].nil?
      raise ArgumentError.new("You must supply a Hash with :template_body to this expectation")
    end
    stack[:parameters] ||= {}

    change_set_name = "CloudSpec-#{SecureRandom.uuid}"
    client = Aws::CloudFormation::Client.new
    change_set_id = client.create_change_set(
      change_set_name: change_set_name,
      stack_name: change_set_name,
      change_set_type: 'CREATE',
      template_body: stack[:template_body],
      parameters: stack[:parameters].map { |k, v| {parameter_key: k, parameter_value: v} }
    ).id
    if wait_change_set_complete(client, change_set_id)
      client.delete_stack(stack_name: change_set_id)
    end
    response = client.describe_change_set(change_set_name: change_set_id, stack_name: change_set_name)
    client.delete_change_set(change_set_name: change_set_id)

    response
  end

  def wait_change_set_complete(client, change_set_id)
    client.wait_until(:change_set_create_complete, {change_set_name: change_set_id, stack_name: change_set_id}, {delay: 2, max_attempts: 15})
    true
  rescue Aws::Waiters::Errors::WaiterFailed
    false
  end
end

RSpec::Matchers.define :contain_in_change_set do |resource_type, resource_id|
  include CloudSpec::ChangeSet
  match do |stack|
    change_set_result = create_change_set(stack)
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
  include CloudSpec::ChangeSet
  match do |stack|
    change_set_result = create_change_set(stack)
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
