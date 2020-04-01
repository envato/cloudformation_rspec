SparkleFormation.new(:vpc,
  {
    compile_time_parameters: {
      vpc_cidr: {
        type: :string,
      }
    }
  }
) do
  parameters.vpc_cidr do
    description 'VPC CIDR'
    type 'String'
    constraint_description 'CIDR block parameter must be in the form x.x.x.x/16-28'
    default state!(:vpc_cidr)
  end

  resources.vpc do
    type "AWS::EC2::VPC"
    properties do
      cidr_block ref!(:vpc_cidr)
    end
  end
end
