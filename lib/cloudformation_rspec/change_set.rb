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

  InvalidSparkleTemplate = Class.new(StandardError)
  InvalidCloudFormationTemplate = Class.new(StandardError)
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

  def self.from_sparkleformation_template(sparkle_path:, template_file:, compile_state:, parameters:)
    begin
      ::SparkleFormation.sparkle_path = sparkle_path
      sparkle_template = ::SparkleFormation.compile(File.join(sparkle_path, template_file), :sparkle)
    rescue => error
      raise InvalidSparkleTemplate.new("Error compiling template into SparkleTemplate #{error.message}")
    end

    begin
      sparkle_template.compile_state = compile_state
      template_body = sparkle_template.to_json
    rescue => error
      raise InvalidCloudFormationTemplate.new("Error compiling template into CloudFormation #{error.message}")
    end
  
    new(template_body: template_body, parameters: parameters).tap { |change_set| change_set.create_change_set }
  end

  def create_change_set
    change_set_hash = generate_change_set_hash

    if change_set = self.class.get_from_cache(change_set_hash)
      return change_set
    end

    client = Aws::CloudFormation::Client.new
    change_set = client.create_change_set(
      change_set_name: change_set_name,
      stack_name: change_set_name,
      change_set_type: 'CREATE',
      template_body: @template_body,
      parameters: flat_parameters
    )
    @change_set_id = change_set.id
    if wait_change_set_complete(client, @change_set_id)
      client.delete_stack(stack_name: @change_set_id)
    end
    response = client.describe_change_set(change_set_name: @change_set_id, stack_name: change_set_name)
    if !END_STATES.include? response.status
      raise ChangeSetNotComplete.new("Change set did not complete in time. #{response.status}")
    end
    @status = response.status
    @changes = response.changes.map { |change| CloudFormationRSpec::ResourceChange.new(change.resource_change.resource_type, change.resource_change.logical_resource_id) }
    client.delete_change_set(change_set_name: @change_set_id)
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

  def wait_change_set_complete(client, change_set_id)
    client.wait_until(:stack_exists, {stack_name: change_set_id}, {delay: WAIT_DELAY})
    client.wait_until(:change_set_create_complete, {change_set_name: change_set_id, stack_name: change_set_id}, {delay: WAIT_DELAY})
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
