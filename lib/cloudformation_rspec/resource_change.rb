class CloudFormationRSpec::ResourceChange
  attr_reader :resource_type, :logical_resource_id

  def initialize(resource_type, logical_resource_id)
    @resource_type = resource_type
    @logical_resource_id = logical_resource_id
  end

  def ==(expected)
    expected.is_a?(self.class) && self.resource_type == expected.resource_type && self.logical_resource_id == expected.logical_resource_id
  end
end
