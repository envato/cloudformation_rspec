require 'rspec'
require 'aws-sdk-cloudformation'
require 'securerandom'
require 'digest'
require 'sparkle_formation'

module CloudFormationRSpec::ChangeSet
  END_STATES = [
    'CREATE_COMPLETE',
    'DELETE_COMPLETE',
    'FAILED'
  ]
  WAIT_DELAY = 3

  InvalidSparkleTemplate = Class.new(StandardError)
  InvalidCloudFormationTemplate = Class.new(StandardError)
  ChangeSetNotComplete = Class.new(StandardError)

  @change_set_cache = {}

  def compile_sparkleformation_template(sparkle_path, template_file, compile_state)
    begin
      ::SparkleFormation.sparkle_path = sparkle_path
      sparkle_template = ::SparkleFormation.compile(File.join(sparkle_path, template_file), :sparkle)
    rescue => error
      raise InvalidSparkleTemplate.new("Error compiling template into SparkleTemplate #{error.message}")
    end
  
  
    begin
      sparkle_template.compile_state = compile_state
      sparkle_template.to_json
    rescue => error
      raise InvalidCloudFormationTemplate.new("Error compiling template into CloudFormation #{error.message}")
    end
  end

  def create_change_set(stack)
    if !stack.is_a?(Hash)
      raise ArgumentError.new("You must supply a Hash to this expectation")
    end

    if stack[:compiler] == :sparkleformation
      stack[:template_body] = compile_sparkleformation_template(stack[:sparkle_path], stack[:template_file], stack[:compile_state])
    end
    create_change_set_from_cloudformation(stack)
  end

  def create_change_set_from_cloudformation(stack)
    if stack[:template_body].nil?
      raise ArgumentError.new("You must supply a Hash with :template_body to this expectation")
    end
    stack[:parameters] ||= {}

    change_set_hash = generate_change_set_hash(stack)

    if change_set = CloudFormationRSpec::ChangeSet.get_from_cache(change_set_hash)
      return change_set
    end

    change_set_name = "CloudFormationRSpec-#{SecureRandom.uuid}"
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
    if !END_STATES.include? response.status
      raise ChangeSetNotComplete.new("Change set did not complete in time. #{response.status}")
    end
    client.delete_change_set(change_set_name: change_set_id)

    CloudFormationRSpec::ChangeSet.add_to_cache(change_set_hash, response)
    response
  end

  private

  def wait_change_set_complete(client, change_set_id)
    client.wait_until(:stack_exists, {stack_name: change_set_id}, {delay: WAIT_DELAY})
    client.wait_until(:change_set_create_complete, {change_set_name: change_set_id, stack_name: change_set_id}, {delay: WAIT_DELAY})
  rescue Aws::Waiters::Errors::WaiterFailed, Aws::Waiters::Errors::TooManyAttemptsError
    false
  end

  def generate_change_set_hash(stack)
    Digest::MD5.hexdigest(stack[:template_body] + stack[:parameters].to_json)
  end

  def self.get_from_cache(change_set_hash)
    @change_set_cache[change_set_hash]
  end

  def self.add_to_cache(change_set_hash, change_set)
    @change_set_cache[change_set_hash] = change_set
  end

  def self.flush_cache
    @change_set_cache = {}
  end
end

RSpec::Matchers.define :contain_in_change_set do |resource_type, resource_id|
  include CloudFormationRSpec::ChangeSet
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
  include CloudFormationRSpec::ChangeSet
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
