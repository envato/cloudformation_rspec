class CloudFormationRSpec::ResourceChange
  attr_reader :resource_type, :logical_resource_id

  def initialize(resource_type, logical_resource_id)
    @resource_type = resource_type
    @logical_resource_id = logical_resource_id
  end
end
