require 'aws-sdk-cloudformation'
require 'securerandom'
require 'digest'
require 'sparkle_formation'

class CloudFormationRSpec::ChangeSet
  END_STATES = [
    'CREATE_COMPLETE',
    'DELETE_COMPLETE',
    'FAILED'
  ]
  WAIT_DELAY = 3

  ChangeSetNotComplete = Class.new(StandardError)

  @change_set_cache = {}

  attr_reader :changes, :status

  def initialize(template_body:, parameters: {})
    @template_body = template_body
    @parameters = parameters ? parameters : {}
  end

  def self.from_cloudformation_template(template_body:, parameters:)
    new(template_body: template_body, parameters: parameters).tap { |change_set| change_set.create_change_set }
  end

  def self.from_sparkleformation_template(template_file:, compile_state:, parameters:)
    template_body = CloudFormationRSpec::Sparkle.compile_sparkle_template(template_file, compile_state)
  
    new(template_body: template_body, parameters: parameters).tap { |change_set| change_set.create_change_set }
  end

  def create_change_set
    change_set_hash = generate_change_set_hash

    if change_set = self.class.get_from_cache(change_set_hash)
      @status = change_set.status
      @changes = change_set.changes.map { |change| CloudFormationRSpec::ResourceChange.new(change.resource_change.resource_type, change.resource_change.logical_resource_id) }
      return change_set
    end

    client = Aws::CloudFormation::Client.new
    change_set = client.create_change_set(
      change_set_name: change_set_name,
      stack_name: change_set_name,
      change_set_type: 'CREATE',
      template_body: @template_body,
      parameters: flat_parameters,
      capabilities: ['CAPABILITY_IAM', 'CAPABILITY_NAMED_IAM'],
    )
    @change_set_id = change_set.id
    wait_change_set_review(client, @change_set_id)
    response = client.describe_change_set(change_set_name: @change_set_id, stack_name: change_set_name)
    if !END_STATES.include? response.status
      raise ChangeSetNotComplete.new("Change set did not complete in time. #{response.status}")
    end
    @status = response.status
    @changes = response.changes.map { |change| CloudFormationRSpec::ResourceChange.new(change.resource_change.resource_type, change.resource_change.logical_resource_id) }
    client.delete_change_set(change_set_name: @change_set_id)
    client.delete_stack(stack_name: @change_set_id)
    self.class.add_to_cache(change_set_hash, response)
    response
  end

  private

  def change_set_name
    @change_set_name ||= "CloudFormationRSpec-#{SecureRandom.uuid}"
  end

  def flat_parameters
    @parameters.map { |k, v| {parameter_key: k, parameter_value: v} }
  end

  def wait_change_set_review(client, change_set_id)
    client.wait_until(:stack_exists, {stack_name: change_set_id}, {delay: WAIT_DELAY})
    retries = 10
    while do
      resp = client.describe_stacks(stack_name: change_set_id)
      if resp.stacks.first.stack_status == 'REVIEW_IN_PROGRESS'
        return true
      end
      retries--
      if retries <= 0
        return false
      end
      sleep WAIT_DELAY
    end
  rescue Aws::Waiters::Errors::WaiterFailed, Aws::Waiters::Errors::TooManyAttemptsError
    false
  end

  def generate_change_set_hash
    Digest::MD5.hexdigest(@template_body + @parameters.to_json)
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
